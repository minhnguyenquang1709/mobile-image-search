const dimensions = 512;

enum Model {
  vitBase32SigLip2_256,
  vitBase16SigLipi18_256,
  vitBase16QuickGelu_224,
}

const models = {
  Model.vitBase32SigLip2_256: {
    "textEncoder":
        "assets/openclip/ViT-B-32-SigLIP2-256/text_encoder_quant.onnx",
    "imageEncoder":
        "assets/openclip/ViT-B-32-SigLIP2-256/image_encoder_quant.onnx",
    "mean": [0.5, 0.5, 0.5],
    "std": [0.5, 0.5, 0.5],
    "imageSize": 256,
    "contextLength": 64,
  },
  Model.vitBase16SigLipi18_256: {
    "textEncoder":
        "assets/openclip/ViT-B-16-SigLIP-i18n-256/text_encoder_quant.onnx",
    "imageEncoder":
        "assets/openclip/ViT-B-16-SigLIP-i18n-256/image_encoder_quant.onnx",
    "mean": [0.5, 0.5, 0.5],
    "std": [0.5, 0.5, 0.5],
    "imageSize": 256,
    "contextLength": 77,
  },
  Model.vitBase16QuickGelu_224: {
    "textEncoder": "assets/openclip/ViT-B-16-quickgelu/text_encoder_quant.onnx",
    "imageEncoder":
        "assets/openclip/ViT-B-16-quickgelu/image_encoder_quant.onnx",
    "mean": [0.48145466, 0.4578275, 0.40821073],
    "std": [0.26862954, 0.26130258, 0.27577711],
    "imageSize": 224,
    "contextLength": 77,
  },
};

const maxIndexAttempts = 3;
const batchSize = 32;
