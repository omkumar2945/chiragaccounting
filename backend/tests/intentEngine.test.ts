import { describe, expect, it } from 'vitest';

import { IntentEngine } from '../src/engines/intentEngine.js';

describe('IntentEngine', () => {
  const engine = new IntentEngine();

  it('detects sales invoice creation', () => {
    expect(engine.detect('Mujhe bill banana hai')).toBe('CREATE_SALES_INVOICE');
  });

  it('detects confirm words', () => {
    expect(engine.detect('haan kar do')).toBe('CONFIRM');
  });

  it('detects cancel words', () => {
    expect(engine.detect('nahi cancel karo')).toBe('CANCEL');
  });

  it('detects navigation', () => {
    expect(engine.detect('Sales kholo')).toBe('OPEN_SALES');
  });
});
