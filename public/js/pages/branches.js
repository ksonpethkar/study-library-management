import { render as renderSeatsHub } from './seats.js';

export async function render() {
  window.location.hash = '#/seats?tab=centers';
  return renderSeatsHub();
}
