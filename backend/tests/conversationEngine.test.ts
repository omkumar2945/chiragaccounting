import { describe, expect, it } from 'vitest';

import { ConversationEngine } from '../src/engines/conversationEngine.js';

describe('ConversationEngine sales flow', () => {
  const engine = new ConversationEngine();

  it('moves through invoice questions to confirmation', () => {
    let snapshot = engine.start('c1', 'CREATE_SALES_INVOICE');

    let step = engine.advance(snapshot, { customer: 'ABC Enterprises' });
    expect(step.needsInputMessage).toContain('Material');
    snapshot = step.snapshot;

    step = engine.advance(snapshot, { item: '6mm toughened glass' });
    expect(step.needsInputMessage).toContain('Quantity');
    snapshot = step.snapshot;

    step = engine.advance(snapshot, { quantity: 100, unit: 'PCS' });
    expect(step.needsInputMessage).toContain('Rate');
    snapshot = step.snapshot;

    step = engine.advance(snapshot, { rate: 450 });
    expect(step.needsInputMessage).toContain('Delivery');
    snapshot = step.snapshot;

    step = engine.advance(snapshot, { deliveryLocation: 'Jaipur' });
    expect(step.needsInputMessage).toContain('Transporter');
    snapshot = step.snapshot;

    step = engine.advance(snapshot, { transporter: 'Balaji' });
    expect(step.needsInputMessage).toContain('Vehicle');
    snapshot = step.snapshot;

    step = engine.advance(snapshot, { vehicleNumber: 'RJ14AB1234' });
    expect(step.awaitingConfirmation).toBe(true);
    expect(step.draftReadyMessage).toContain('Invoice ready');
  });
});
