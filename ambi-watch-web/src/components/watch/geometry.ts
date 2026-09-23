interface Point {
  x: number;
  y: number;
}

export interface Circle {
  cx: number;
  cy: number;
  r: number;
}

const fmt = (n: number) => Number(n.toFixed(2));
const sub = (a: Point, b: Point): Point => ({ x: a.x - b.x, y: a.y - b.y });
const add = (a: Point, b: Point): Point => ({ x: a.x + b.x, y: a.y + b.y });
const scale = (a: Point, k: number): Point => ({ x: a.x * k, y: a.y * k });
const len = (a: Point) => Math.hypot(a.x, a.y);

/** Centre of the fillet circle tangent to both circles, on the given side of c1→c2. */
function filletCenter(c1: Circle, c2: Circle, f: number, side: 1 | -1): Point {
  const p1 = { x: c1.cx, y: c1.cy };
  const p2 = { x: c2.cx, y: c2.cy };
  const d = len(sub(p2, p1));
  const a = c1.r + f;
  const b = c2.r + f;
  const along = (a * a - b * b + d * d) / (2 * d);
  const across = Math.sqrt(Math.max(a * a - along * along, 0));
  const u = scale(sub(p2, p1), 1 / d);
  const n = { x: -u.y * side, y: u.x * side };
  return add(add(p1, scale(u, along)), scale(n, across));
}

function tangent(c: Circle, fillet: Point): Point {
  const center = { x: c.cx, y: c.cy };
  const v = sub(fillet, center);
  return add(center, scale(v, c.r / len(v)));
}

function arc(r: number, from: Point, to: Point, center: Point, sweep: 0 | 1): string {
  const a0 = Math.atan2(from.y - center.y, from.x - center.x);
  const a1 = Math.atan2(to.y - center.y, to.x - center.x);
  let span = sweep === 1 ? a1 - a0 : a0 - a1;
  while (span < 0) span += Math.PI * 2;
  const large = span > Math.PI ? 1 : 0;
  return `A ${fmt(r)} ${fmt(r)} 0 ${large} ${sweep} ${fmt(to.x)} ${fmt(to.y)}`;
}

/**
 * Outline of circles chained in order and joined by concave fillets
 * ("gooey" metaball). `fillet` is the fillet radius; larger values give a
 * thicker neck. Used by the control bar and the power-off pairs.
 */
export function gooeyPath(circles: Circle[], fillet: number): string {
  if (circles.length === 1) {
    const [c] = circles;
    return `M ${c.cx - c.r} ${c.cy} a ${c.r} ${c.r} 0 1 0 ${c.r * 2} 0 a ${c.r} ${c.r} 0 1 0 ${-c.r * 2} 0 Z`;
  }
  const pairs = circles.slice(0, -1).map((c, i) => {
    const next = circles[i + 1];
    const left = filletCenter(c, next, fillet, -1);
    const right = filletCenter(c, next, fillet, 1);
    return {
      left: { center: left, a: tangent(c, left), b: tangent(next, left) },
      right: { center: right, a: tangent(c, right), b: tangent(next, right) },
    };
  });

  const center = (c: Circle): Point => ({ x: c.cx, y: c.cy });
  const last = circles.length - 1;
  const parts: string[] = [];
  const start = pairs[0].right.a;
  parts.push(`M ${fmt(start.x)} ${fmt(start.y)}`);
  parts.push(arc(circles[0].r, start, pairs[0].left.a, center(circles[0]), 1));
  pairs.forEach((pair, i) => {
    parts.push(arc(fillet, pair.left.a, pair.left.b, pair.left.center, 0));
    const to = i + 1 < last ? pairs[i + 1].left.a : pairs[i].right.b;
    parts.push(arc(circles[i + 1].r, pair.left.b, to, center(circles[i + 1]), 1));
  });
  for (let i = pairs.length - 1; i >= 0; i--) {
    const pair = pairs[i];
    parts.push(arc(fillet, pair.right.b, pair.right.a, pair.right.center, 0));
    if (i > 0) parts.push(arc(circles[i].r, pair.right.a, pairs[i - 1].right.b, center(circles[i]), 1));
  }
  parts.push("Z");
  return parts.join(" ");
}

export interface SheetShape {
  width: number;
  height: number;
  radiusTop: number;
  radiusBottom: number;
  /** Concave notch on the right edge, around the scroll/page indicator. */
  notch?: { center: number; depth: number; half: number };
}

/** Rounded sheet whose right edge bows inward around the crown-side indicator (02, 06). */
export function sheetPath({ width: w, height: h, radiusTop: rt, radiusBottom: rb, notch }: SheetShape): string {
  const inset = (y: number) => {
    let x = 0;
    if (y < rt) x = Math.max(x, rt - Math.sqrt(rt * rt - (rt - y) ** 2));
    if (y > h - rb) x = Math.max(x, rb - Math.sqrt(rb * rb - (y - (h - rb)) ** 2));
    if (notch && Math.abs(y - notch.center) < notch.half) {
      x = Math.max(x, (notch.depth * (1 + Math.cos((Math.PI * (y - notch.center)) / notch.half))) / 2);
    }
    return x;
  };
  const points: string[] = [];
  const step = 2;
  for (let y = 0; y <= h; y += step) points.push(`${fmt(w - inset(y))} ${y}`);
  if (h % step) points.push(`${fmt(w - inset(h))} ${h}`);
  return [
    `M ${rt} 0`,
    `L ${points.join(" L ")}`,
    `L ${rb} ${h}`,
    `A ${rb} ${rb} 0 0 1 0 ${h - rb}`,
    `L 0 ${rt}`,
    `A ${rt} ${rt} 0 0 1 ${rt} 0`,
    "Z",
  ].join(" ");
}
