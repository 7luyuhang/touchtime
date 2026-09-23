export type FontFamilyToken = "sans" | "mono" | "watch" | "watch-serif";

export interface TypeStyle {
  fontFamily: FontFamilyToken;
  fontSize: number;
  fontWeight: 400 | 500 | 600;
  lineHeight: number;
  letterSpacing: number;
}

/**
 * `sampled` values were measured from the reference images (pixel positions,
 * colours, curve fits); `assumed` values are inferences the images cannot
 * confirm (font families, blur, motion).
 */
export type AmbiTokenStatus = "sampled" | "assumed";

export interface AmbiToken {
  value: string;
  status: AmbiTokenStatus;
  source: string;
  note?: string;
}

export interface AmbiTypeToken extends TypeStyle {
  status: AmbiTokenStatus;
  source: string;
  note?: string;
}
