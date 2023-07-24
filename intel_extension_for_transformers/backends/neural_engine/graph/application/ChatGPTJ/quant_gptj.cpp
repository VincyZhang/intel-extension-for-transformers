//  Copyright (c) 2023 Intel Corporation
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

#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <map>
#include <regex>
#include <string>
#include <vector>

#include "application/common.h"
#include "core/ne.h"

// default hparams (GPT-J 6B)
struct gptj_hparams {
  int32_t n_vocab = 50400;
  int32_t n_ctx = 2048;
  int32_t n_embd = 4096;
  int32_t n_head = 16;
  int32_t n_layer = 28;
  int32_t n_rot = 64;
  int32_t ftype = 1;
};

// quantize a model
bool gptj_model_quantize(const std::string& fname_inp, const std::string& fname_out, ne_ftype ftype) {
  gpt_vocab vocab;

  printf("%s: loading model from '%s'\n", __func__, fname_inp.c_str());

  auto finp = std::ifstream(fname_inp, std::ios::binary);
  if (!finp) {
    fprintf(stderr, "%s: failed to open '%s' for reading\n", __func__, fname_inp.c_str());
    return false;
  }

  auto fout = std::ofstream(fname_out, std::ios::binary);
  if (!fout) {
    fprintf(stderr, "%s: failed to open '%s' for writing\n", __func__, fname_out.c_str());
    return false;
  }

  // verify magic
  {
    uint32_t magic;
    finp.read((char*)&magic, sizeof(magic));
    if (magic != NE_FILE_MAGIC) {
      fprintf(stderr, "%s: invalid model file '%s' (bad magic)\n", __func__, fname_inp.c_str());
      return false;
    }

    fout.write((char*)&magic, sizeof(magic));
  }

  gptj_hparams hparams;

  // load hparams
  {
    finp.read((char*)&hparams.n_vocab, sizeof(hparams.n_vocab));
    finp.read((char*)&hparams.n_ctx, sizeof(hparams.n_ctx));
    finp.read((char*)&hparams.n_embd, sizeof(hparams.n_embd));
    finp.read((char*)&hparams.n_head, sizeof(hparams.n_head));
    finp.read((char*)&hparams.n_layer, sizeof(hparams.n_layer));
    finp.read((char*)&hparams.n_rot, sizeof(hparams.n_rot));
    finp.read((char*)&hparams.ftype, sizeof(hparams.ftype));

    const int32_t qntvr_src = hparams.ftype / NE_QNT_VERSION_FACTOR;
    const int32_t ftype_dst = NE_QNT_VERSION * NE_QNT_VERSION_FACTOR + ftype;

    printf("%s: n_vocab     = %d\n", __func__, hparams.n_vocab);
    printf("%s: n_ctx       = %d\n", __func__, hparams.n_ctx);
    printf("%s: n_embd      = %d\n", __func__, hparams.n_embd);
    printf("%s: n_head      = %d\n", __func__, hparams.n_head);
    printf("%s: n_layer     = %d\n", __func__, hparams.n_layer);
    printf("%s: ftype (src) = %d\n", __func__, hparams.ftype);
    printf("%s: qntvr (src) = %d\n", __func__, qntvr_src);
    printf("%s: ftype (dst) = %d\n", __func__, ftype_dst);
    printf("%s: qntvr (dst) = %d\n", __func__, NE_QNT_VERSION);

    fout.write((char*)&hparams.n_vocab, sizeof(hparams.n_vocab));
    fout.write((char*)&hparams.n_ctx, sizeof(hparams.n_ctx));
    fout.write((char*)&hparams.n_embd, sizeof(hparams.n_embd));
    fout.write((char*)&hparams.n_head, sizeof(hparams.n_head));
    fout.write((char*)&hparams.n_layer, sizeof(hparams.n_layer));
    fout.write((char*)&hparams.n_rot, sizeof(hparams.n_rot));
    fout.write((char*)&ftype_dst, sizeof(ftype_dst));
  }

  // load vocab
  {
    int32_t n_vocab = 0;
    finp.read((char*)&n_vocab, sizeof(n_vocab));
    fout.write((char*)&n_vocab, sizeof(n_vocab));

    if (n_vocab != hparams.n_vocab) {
      fprintf(stderr, "%s: invalid model file '%s' (bad vocab size %d != %d)\n", __func__, fname_inp.c_str(), n_vocab,
              hparams.n_vocab);
      return false;
    }

    std::string word;
    for (int i = 0; i < n_vocab; i++) {
      uint32_t len;
      finp.read((char*)&len, sizeof(len));
      fout.write((char*)&len, sizeof(len));

      word.resize(len);
      finp.read((char*)word.data(), len);
      fout.write((char*)word.data(), len);

      vocab.token_to_id[word] = i;
      vocab.id_to_token[i] = word;
    }
  }

  // regexes of tensor names to be quantized
  const std::vector<std::string> to_quant = {
      ".*weight",
  };

  //if (!ne_common_quantize_0(finp, fout, ftype, to_quant, {"transformer.wte.weight"})) {
  if (!ne_common_quantize_0(finp, fout, ftype, to_quant, {})) {
    fprintf(stderr, "%s: failed to quantize model '%s'\n", __func__, fname_inp.c_str());
    return false;
  }

  finp.close();
  fout.close();

  return true;
}

int main(int argc, char** argv) {
  quant_params q_params;
  if (quant_params_parse(argc, argv, q_params) == false) {
    return 1;
  }
  const std::string fname_inp = q_params.model_file;
  const std::string fname_out = q_params.out_file;
  if (!isValidFilename(fname_inp)) {
    fprintf(stderr, "invalid file names '%s'\n", fname_inp.c_str());
    return 1;
  }
  ne_ftype ftype = NE_FTYPE_MAP[
      std::make_tuple(q_params.bits, q_params.alg, q_params.block_size, q_params.scale_dtype, q_params.gemm_isa)];

  // needed to initialize f16 tables
  {
    struct ne_init_params params = {0, NULL, false};
    struct ne_context* ctx = ne_init(params);
    ne_free(ctx);
  }

  const int64_t t_main_start_us = ne_time_us();

  int64_t t_quantize_us = 0;

  // load the model
  {
    const int64_t t_start_us = ne_time_us();

    if (!gptj_model_quantize(fname_inp, fname_out, ne_ftype(ftype))) {
      fprintf(stderr, "%s: failed to quantize model from '%s'\n", __func__, fname_inp.c_str());
      return 1;
    }

    t_quantize_us = ne_time_us() - t_start_us;
  }

  // report timing
  {
    const int64_t t_main_end_us = ne_time_us();

    printf("\n");
    printf("%s: quantize time = %8.2f ms\n", __func__, t_quantize_us / 1000.0f);
    printf("%s:    total time = %8.2f ms\n", __func__, (t_main_end_us - t_main_start_us) / 1000.0f);
  }

  return 0;
}
