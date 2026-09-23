export type FontFamilyToken = "sans" | "mono";

export interface TypeStyle {
  fontFamily: FontFamilyToken;
  fontSize: number;
  fontWeight: 400 | 500 | 600;
  lineHeight: number;
  letterSpacing: number;
}

/**
 * `placeholder` tokens borrow a Vercel base value until the matching Figma
 * variable is pulled; `figma` tokens carry the value read from the file.
 */
export type AmbiTokenStatus = "placeholder" | "figma";

export interface AmbiToken {
  value: string;
  status: AmbiTokenStatus;
  aliasOf?: string;
  figmaVariable?: string;
  note?: string;
}
