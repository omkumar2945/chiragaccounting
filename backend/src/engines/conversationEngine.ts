import { CommandIntent, ConversationState } from '../domain/enums.js';
import { ConversationSnapshot } from '../domain/models.js';
import { ExtractedEntities } from './entityEngine.js';

interface ConversationAdvanceResult {
  snapshot: ConversationSnapshot;
  needsInputMessage?: string;
  awaitingConfirmation?: boolean;
  draftReadyMessage?: string;
}

export class ConversationEngine {
  start(conversationId: string, intent: CommandIntent): ConversationSnapshot {
    if (intent === 'CREATE_SALES_INVOICE') {
      return {
        conversationId,
        status: 'ACTIVE',
        currentIntent: intent,
        pendingField: 'customer',
        pendingQuestion: 'Customer ka naam batayiye.',
        context: {},
      };
    }

    return {
      conversationId,
      status: 'ACTIVE',
      currentIntent: intent,
      pendingField: null,
      pendingQuestion: null,
      context: {},
    };
  }

  advance(snapshot: ConversationSnapshot, entities: ExtractedEntities): ConversationAdvanceResult {
    const context = { ...snapshot.context };
    let pendingField = snapshot.pendingField;
    let pendingQuestion = snapshot.pendingQuestion;
    let status: ConversationState = snapshot.status;

    if (snapshot.currentIntent !== 'CREATE_SALES_INVOICE') {
      return { snapshot };
    }

    if (pendingField === 'customer') {
      if (entities.customer != null) {
        context.customer = entities.customer;
        pendingField = 'item';
        pendingQuestion = 'Material ka naam batayiye.';
        return {
          snapshot: { ...snapshot, context, pendingField, pendingQuestion, status },
          needsInputMessage: 'Customer select kar liya. Material ka naam batayiye.',
        };
      }
      return {
        snapshot,
        needsInputMessage: 'Customer ka naam batayiye.',
      };
    }

    if (pendingField === 'item') {
      if (entities.item != null || entities.customer != null) {
        context.item = entities.item ?? entities.customer;
        pendingField = 'quantity';
        pendingQuestion = 'Quantity kitni hai?';
        return {
          snapshot: { ...snapshot, context, pendingField, pendingQuestion, status },
          needsInputMessage: 'Quantity kitni hai?',
        };
      }
      return { snapshot, needsInputMessage: 'Material ka naam batayiye.' };
    }

    if (pendingField === 'quantity') {
      if (entities.quantity != null) {
        context.quantity = entities.quantity;
        context.unit = entities.unit ?? 'PCS';
        pendingField = 'rate';
        pendingQuestion = 'Rate kya hai?';
        return {
          snapshot: { ...snapshot, context, pendingField, pendingQuestion, status },
          needsInputMessage: 'Rate kya hai?',
        };
      }
      return { snapshot, needsInputMessage: 'Quantity kitni hai?' };
    }

    if (pendingField === 'rate') {
      if (entities.rate != null) {
        context.rate = entities.rate;
        pendingField = 'deliveryLocation';
        pendingQuestion = 'Delivery location?';
        return {
          snapshot: { ...snapshot, context, pendingField, pendingQuestion, status },
          needsInputMessage: 'Delivery location?',
        };
      }
      return { snapshot, needsInputMessage: 'Rate kya hai?' };
    }

    if (pendingField === 'deliveryLocation') {
      if (entities.deliveryLocation != null || entities.customer != null) {
        context.deliveryLocation = entities.deliveryLocation ?? entities.customer;
        pendingField = 'transporter';
        pendingQuestion = 'Transporter ka naam batayiye.';
        return {
          snapshot: { ...snapshot, context, pendingField, pendingQuestion, status },
          needsInputMessage: 'Transporter ka naam batayiye.',
        };
      }
      return { snapshot, needsInputMessage: 'Delivery location batayiye.' };
    }

    if (pendingField === 'transporter') {
      if (entities.transporter != null || entities.customer != null) {
        context.transporter = entities.transporter ?? entities.customer;
        pendingField = 'vehicleNumber';
        pendingQuestion = 'Vehicle number?';
        return {
          snapshot: { ...snapshot, context, pendingField, pendingQuestion, status },
          needsInputMessage: 'Vehicle number?',
        };
      }
      return { snapshot, needsInputMessage: 'Transporter ka naam batayiye.' };
    }

    if (pendingField === 'vehicleNumber') {
      if (entities.vehicleNumber != null) {
        context.vehicleNumber = entities.vehicleNumber;
        const quantity = Number(context.quantity ?? 0);
        const rate = Number(context.rate ?? 0);
        const amount = quantity * rate;
        const gst = amount * 0.18;
        const total = amount + gst;

        context.amount = amount;
        context.gst = gst;
        context.total = total;

        status = 'WAITING_FOR_CONFIRMATION';
        pendingField = null;
        pendingQuestion = null;
        return {
          snapshot: { ...snapshot, context, pendingField, pendingQuestion, status },
          awaitingConfirmation: true,
          draftReadyMessage: `Invoice ready hai. Total Rs ${total.toFixed(2)} hai. Post kar doon?`,
        };
      }
      return { snapshot, needsInputMessage: 'Vehicle number batayiye.' };
    }

    return {
      snapshot: { ...snapshot, context, pendingField, pendingQuestion, status },
    };
  }
}
