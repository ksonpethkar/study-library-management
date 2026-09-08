/**
 * Branches / Study Centers Page Delegator
 * Branches management is integrated directly into the Centers & Seating Hub (seats.js?tab=centers).
 * This module redirects any legacy #/branches navigation to #/seats?tab=centers.
 */
import { render as renderSeats } from "./seats.js";

export async function render(params) {
  window.location.hash = "#/seats?tab=centers";
  return renderSeats(params);
}

export default { render };

