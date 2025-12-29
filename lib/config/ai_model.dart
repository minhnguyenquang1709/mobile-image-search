const dimensions = 768;

enum Model { vitBase32SigLip2_256 }

const models = {
  Model.vitBase32SigLip2_256: {
    "textEncoder":
        "assets/openclip/ViT-B-32-SigLIP2-256/text_encoder_quant.onnx",
    "imageEncoder":
        "assets/openclip/ViT-B-32-SigLIP2-256/image_encoder_quant.onnx",
  },
};
