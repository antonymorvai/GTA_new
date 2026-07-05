'use client';

/**
 * SVG-Karte des GTA-V-Koordinatenraums (x -4600..4600, y -4400..8200).
 * Bewusst ohne Map-Bild (Copyright) — Raster + Küstenlinien-Andeutung reichen
 * für Replay/Live-Analyse; ein Kartenbild kann später als Layer ergänzt werden.
 */

export const WORLD = { minX: -4600, maxX: 4600, minY: -4400, maxY: 8200 };
export const VIEW = { w: 640, h: 880 };

export function toSvg(x: number, y: number): { x: number; y: number } {
  return {
    x: ((x - WORLD.minX) / (WORLD.maxX - WORLD.minX)) * VIEW.w,
    y: ((WORLD.maxY - y) / (WORLD.maxY - WORLD.minY)) * VIEW.h,
  };
}

export default function GameMap({ children }: { children: React.ReactNode }) {
  const gridLines = [];
  for (let gx = WORLD.minX; gx <= WORLD.maxX; gx += 1000) {
    const { x } = toSvg(gx, 0);
    gridLines.push(<line key={`x${gx}`} x1={x} y1={0} x2={x} y2={VIEW.h} stroke="#ffffff10" />);
  }
  for (let gy = WORLD.minY; gy <= WORLD.maxY; gy += 1000) {
    const { y } = toSvg(0, gy);
    gridLines.push(<line key={`y${gy}`} x1={0} y1={y} x2={VIEW.w} y2={y} stroke="#ffffff10" />);
  }

  return (
    <svg viewBox={`0 0 ${VIEW.w} ${VIEW.h}`} className="w-full max-w-xl bg-[#0b1220] rounded-lg border border-white/10">
      {gridLines}
      {/* grobe Orientierung: Stadtzentrum & Nordufer */}
      <text {...toSvg(0, -800)} fill="#4b5563" fontSize="11">Los Santos</text>
      <text {...toSvg(-300, 3600)} fill="#4b5563" fontSize="11">Sandy Shores</text>
      <text {...toSvg(-300, 6400)} fill="#4b5563" fontSize="11">Paleto Bay</text>
      {children}
    </svg>
  );
}
