import { cleanup, fireEvent, render } from '@testing-library/react';
import { afterEach, expect, test, vi } from 'vitest';
import { omok } from '@jgame/engine';
import { OmokBoard } from '../src/boards/OmokBoard';
afterEach(cleanup);
test('clicking an empty cell on my turn sends the move', () => {
  const onMove = vi.fn();
  const { container } = render(<OmokBoard state={omok.initialState()} mySeat={0} myTurn onMove={onMove} />);
  fireEvent.click(container.querySelector('[data-cell="3,4"]')!);
  expect(onMove).toHaveBeenCalledWith({ x: 3, y: 4 });
});
test('clicks are ignored when not my turn or cell is occupied', () => {
  const onMove = vi.fn();
  const state = omok.applyMove(omok.initialState(), { x: 3, y: 4 });
  const { container, rerender } = render(<OmokBoard state={state} mySeat={1} myTurn={false} onMove={onMove} />);
  fireEvent.click(container.querySelector('[data-cell="2,4"]')!);
  rerender(<OmokBoard state={state} mySeat={1} myTurn onMove={onMove} />);
  fireEvent.click(container.querySelector('[data-cell="3,4"]')!);
  expect(onMove).not.toHaveBeenCalled();
});
