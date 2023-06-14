//  Copyright (c) 2022 Intel Corporation
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
#include "mha_dense_static.hpp"
#include <utility>
#include "src/cpu/kernels/mha_dense_ref.hpp"

namespace bench {
std::pair<const void*, const void*> make_tensor_obj(const jd::tensor_desc& ts_desc, float min_value = -10,
                                                    float max_value = 10) {
  int64_t elem_num = ts_desc.size();
  if (elem_num == 0) return {nullptr, nullptr};
  int bytes_size = elem_num * jd::type_size[ts_desc.dtype()];
  void* data_ptr = nullptr;
  if (min_value == 0.f && max_value == 0.f) {
    data_ptr = aligned_allocator_t<uint8_t>::allocate(pad_to(bytes_size, 64), true);
    memset(data_ptr, 0, bytes_size);
  } else {
    if (ts_desc.dtype() == jd::data_type::fp32) {
      data_ptr = aligned_allocator_t<float>::allocate(pad_to(elem_num, 16));
      init_vector(static_cast<float*>(data_ptr), elem_num, min_value, max_value);
    } else if (ts_desc.dtype() == jd::data_type::bf16) {
      data_ptr = aligned_allocator_t<jd::bfloat16_t>::allocate(pad_to(elem_num, 32));
      init_vector(static_cast<jd::bfloat16_t*>(data_ptr), elem_num, min_value, max_value);
    } else if (ts_desc.dtype() == jd::data_type::s32) {
      data_ptr = aligned_allocator_t<int32_t>::allocate(pad_to(elem_num, 16));
      init_vector(static_cast<int32_t*>(data_ptr), elem_num, min_value, max_value);
    } else if (ts_desc.dtype() == jd::data_type::u8) {
      data_ptr = aligned_allocator_t<uint8_t>::allocate(pad_to(elem_num, 64));
      init_vector(static_cast<uint8_t*>(data_ptr), elem_num, min_value, max_value);
    } else if (ts_desc.dtype() == jd::data_type::s8) {
      data_ptr = aligned_allocator_t<int8_t>::allocate(pad_to(elem_num, 64));
      init_vector(static_cast<int8_t*>(data_ptr), elem_num, min_value, max_value);
    } else {
      SPARSE_LOG(FATAL) << "Unexpected dtype!";
    }
  }
  void* data_ptr_copy = aligned_allocator_t<uint8_t>::allocate(pad_to(bytes_size, 64), true);
  memcpy(data_ptr_copy, data_ptr, bytes_size);
  return {data_ptr, data_ptr_copy};
}
double mha_dense_static_bench::calc_flop() const {
  double flops = 0;
  flops += 2. * sl_m * head_size * sl_n;  // Q x K
  flops += 6. * sl_m * sl_n;              // softmax: 1max + 3reduction + 2softmax  (copied from softmax benchmark)
  flops += 2. * sl_n * sl_m * head_size;  // A x V
  flops *= head_num * batch_size;
  return flops;
}
bench_res_t mha_dense_static_bench::set_config(int argc, char** argv) {
  if (argc < MIN_ARG_NUM) {
    LOG(ERROR) << "Not enough arguments passed";
    return {bench_status::wrong_input};
  }
  LOG(INFO) << "mha_dense_static\n";
  batch_size = str_to_num<int64_t>(argv[0]);
  sl_m = str_to_num<int64_t>(argv[1]);
  head_num = str_to_num<int64_t>(argv[2]);
  head_size = str_to_num<int64_t>(argv[3]);
  dt_dst = (argc <= 4)                    ? jd::data_type::u8
           : strcmp(argv[4], "fp32") == 0 ? jd::data_type::fp32
           : strcmp(argv[4], "s8") == 0   ? jd::data_type::s8
           : strcmp(argv[4], "u8") == 0   ? jd::data_type::u8
           : strcmp(argv[4], "bf16") == 0 ? jd::data_type::bf16
                                          : jd::data_type::undef;
  dt_src = (argc <= 5)                    ? jd::data_type::s8
           : strcmp(argv[5], "s8") == 0   ? jd::data_type::s8
           : strcmp(argv[5], "bf16") == 0 ? jd::data_type::bf16
                                          : jd::data_type::undef;
  if (argc > 6) mask = str_to_num<int32_t>(argv[6]);
  if (argc > 7) badd_dim = str_to_num<int32_t>(argv[7]);
  if (argc > 8) sl_n = str_to_num<int32_t>(argv[8]);
  ft_kv = (argc <= 9)               ? jd::format_type::abcd  //
          : strcmp(argv[9], "abcd") ? jd::format_type::abcd
          : strcmp(argv[9], "acbd") ? jd::format_type::acbd
                                    : jd::format_type::undef;
  if (argc > 10) return {bench_status::wrong_input};
  if (sl_n <= 0) sl_n = sl_m;
  if (mask <= 0) mask = sl_n;
  if (dt_dst == jd::data_type::undef || dt_src == jd::data_type::undef) return {bench_status::wrong_input};
  if (mask > sl_n) return {bench_status::wrong_input};
  if (badd_dim > 4) return {bench_status::wrong_input};
  if (ft_kv == jd::format_type::undef) return {bench_status::wrong_input};
  return {bench_status::success};
}
void mha_dense_static_bench::get_true_data() {
  const auto& q = args.second;
  std::shared_ptr<const jd::kernel_desc_t> mha_dense_ref_desc;
  jd::kernel_desc_t::create<jd::mha_dense_ref_kd_t>(mha_dense_ref_desc, q.op_desc);
  std::shared_ptr<const jd::kernel_t> mha_dense_ref_kernel;
  jd::kernel_t::create<jd::mha_dense_ref_k_t, jd::mha_dense_ref_kd_t>(mha_dense_ref_kernel, mha_dense_ref_desc);
  const auto workspace_q = aligned_allocator_t<char>::allocate(mha_dense_ref_kernel->get_workspace_size());
  std::vector<const void*> data_q(q.rt_data);
  data_q[io::WORKSPACE] = workspace_q;
  mha_dense_ref_kernel->execute(data_q);
  aligned_allocator_t<char>::deallocate(workspace_q);
}
bool mha_dense_static_bench::check_result() {
  const auto& p = args.first;
  const auto& q = args.second;
  std::shared_ptr<const jd::kernel_desc_t> mha_dense_ref_desc;
  jd::kernel_desc_t::create<jd::mha_dense_ref_kd_t>(mha_dense_ref_desc, q.op_desc);
  std::shared_ptr<const jd::kernel_t> mha_dense_ref_kernel;
  jd::kernel_t::create<jd::mha_dense_ref_k_t, jd::mha_dense_ref_kd_t>(mha_dense_ref_kernel, mha_dense_ref_desc);
  mha_dense_ref_kernel->execute(q.rt_data);
  auto buf1 = p.rt_data[io::DST];
  auto size1 = p.op_desc.tensor_descs()[io::DST].size();
  auto buf2 = q.rt_data[io::DST];
  auto size2 = q.op_desc.tensor_descs()[io::DST].size();
  // Should compare buffer with different addresses
  if (buf1 == buf2) return false;
  switch (p.op_desc.tensor_descs()[io::DST].dtype()) {
    case jd::data_type::fp32:
      return compare_data<float>(buf1, size1, buf2, size2, 5e-3);
    case jd::data_type::bf16:
      return compare_data<jd::bfloat16_t>(buf1, size1, buf2, size2, 5e-3);
    case jd::data_type::u8:
      return compare_data<uint8_t>(buf1, size1, buf2, size2, 8e-3);
    case jd::data_type::s8:
      return compare_data<int8_t>(buf1, size1, buf2, size2, 8e-3);
    default:
      SPARSE_LOG(ERROR) << "Unexpected dst type";
  }
  return false;
}
void mha_dense_static_bench::gen_case() {
  op_attrs.clear();
  op_attrs["approx_exp"] = "True";
  op_attrs["stable_softmax"] =
      dt_src == jd::data_type::s8 ? "True" : "False";  // TODO(Yi): change given dt_src is confusing
  if (dt_src == jd::data_type::s8)
    op_attrs["softmax_rescale"] = std::to_string(float{UINT8_MAX});  // TODO(Yi): workaround for accuracy of int8 gptj
  // Step 1: Construct runtime data for equivalent merged spmm
  std::vector<dim_t> badd_full = {batch_size, head_num, sl_m, sl_n};
  ts_descs.assign(io::SIZE, jd::tensor_desc{{}, jd::data_type::undef, jd::format_type::undef});
  ts_descs[io::SRC_Q] = {{batch_size, sl_m, head_num, head_size}, dt_src, jd::format_type::abcd};
  ts_descs[io::SRC_K] = {{batch_size, sl_n, head_num, head_size}, dt_src, ft_kv};
  ts_descs[io::SRC_V] = {{batch_size, sl_n, head_num, head_size}, dt_src, ft_kv};
  if (dt_src != jd::data_type::bf16)
    ts_descs[io::MASK] = {
        {batch_size}, jd::data_type::s32, jd::format_type::a};  // TODO(Yi): change given dt_src is confusing
  ts_descs[io::DST] = {{batch_size, sl_m, head_num, head_size}, dt_dst, jd::format_type::abcd};
  if (badd_dim > 0) {
    SPARSE_LOG_IF(FATAL, badd_dim > 4) << "Unsupported binary add dimension";
    ts_descs[io::BINARY_ADD] = {std::vector<dim_t>(badd_full.cend() - badd_dim, badd_full.cend()), jd::data_type::fp32,
                                jd::plain_format(badd_dim)};
  }
  ts_descs[io::ATT_SCALE] = {{1}, jd::data_type::fp32, jd::format_type::a};
  if (dt_src == jd::data_type::s8) ts_descs[io::Q_SCALE] = {{1}, jd::data_type::fp32, jd::format_type::a};
  if (dt_src == jd::data_type::s8) ts_descs[io::K_SCALE] = {{1}, jd::data_type::fp32, jd::format_type::a};
  if (dt_src == jd::data_type::s8) ts_descs[io::V_SCALE] = {{1}, jd::data_type::fp32, jd::format_type::a};
  ts_descs[io::SRC_DST_SCALE] = {{1}, jd::data_type::fp32, jd::format_type::a};
  ts_descs[io::SRC_DST_ZP] = {{1}, jd::data_type::fp32, jd::format_type::a};
  // Step 2: Construct Tensor ptr
  auto Qs = make_tensor_obj(ts_descs[io::SRC_Q]);
  auto Ks = make_tensor_obj(ts_descs[io::SRC_K]);
  auto Vs = make_tensor_obj(ts_descs[io::SRC_V]);
  auto masks = make_tensor_obj(ts_descs[io::MASK], mask, mask);
  auto dsts = make_tensor_obj(ts_descs[io::DST], 0, 0);
  auto badds = make_tensor_obj(ts_descs[io::BINARY_ADD], -1.f, 1.f);
  auto att_scales = make_tensor_obj(ts_descs[io::ATT_SCALE], 1.f / std::sqrt(sl_n));
  auto q_scales = make_tensor_obj(ts_descs[io::Q_SCALE], 1.1f);
  auto k_scales = make_tensor_obj(ts_descs[io::K_SCALE], 0.9f);
  auto v_scales = make_tensor_obj(ts_descs[io::V_SCALE], 1.2f);
  auto dst_scales = make_tensor_obj(ts_descs[io::SRC_DST_SCALE], 1.2f);
  auto dst_zps = make_tensor_obj(ts_descs[io::SRC_DST_ZP], 10.f);
  std::vector<const void*> data_p(io::SIZE, nullptr);
  data_p[io::SRC_Q] = Qs.first;
  data_p[io::SRC_K] = Ks.first;
  data_p[io::SRC_V] = Vs.first;
  data_p[io::MASK] = masks.first;
  data_p[io::DST] = dsts.first;
  data_p[io::BINARY_ADD] = badds.first;
  data_p[io::ATT_SCALE] = att_scales.first;
  data_p[io::Q_SCALE] = q_scales.first;
  data_p[io::K_SCALE] = k_scales.first;
  data_p[io::V_SCALE] = v_scales.first;
  data_p[io::SRC_DST_SCALE] = dst_scales.first;
  data_p[io::SRC_DST_ZP] = dst_zps.first;
  std::vector<const void*> data_q(io::SIZE, nullptr);
  data_q[io::SRC_Q] = Qs.second;
  data_q[io::SRC_K] = Ks.second;
  data_q[io::SRC_V] = Vs.second;
  data_q[io::MASK] = masks.second;
  data_q[io::DST] = dsts.second;
  data_q[io::BINARY_ADD] = badds.second;
  data_q[io::ATT_SCALE] = att_scales.second;
  data_q[io::Q_SCALE] = q_scales.second;
  data_q[io::K_SCALE] = k_scales.second;
  data_q[io::V_SCALE] = v_scales.second;
  data_q[io::SRC_DST_SCALE] = dst_scales.second;
  data_q[io::SRC_DST_ZP] = dst_zps.second;
  jd::operator_desc op_desc(jd::kernel_kind::mha_dense, jd::kernel_prop::forward_inference, jd::engine_kind::cpu,
                            ts_descs, op_attrs);
  // Step 3: op_args_t testcase pair
  args = {{op_desc, data_p}, {op_desc, data_q}};
}
}  // namespace bench
