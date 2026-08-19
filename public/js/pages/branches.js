import { render as renderSeatsHub } from './seats.js';

export async function render(container) {
  window.location.hash = '#/seats?tab=centers';
  return renderSeatsHub(container);
}
