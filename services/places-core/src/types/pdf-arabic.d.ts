declare module "arabic-reshaper" {
  const ArabicReshaper: {
    convertArabic: (text: string) => string;
  };
  export default ArabicReshaper;
}

declare module "bidi-js" {
  export default function bidiFactory(): {
    getEmbeddingLevels: (text: string) => unknown;
    getReorderedString: (text: string, levels: unknown) => string;
  };
}
