export interface ExtractedEntities {
  customer?: string;
  item?: string;
  quantity?: number;
  unit?: string;
  rate?: number;
  deliveryLocation?: string;
  transporter?: string;
  vehicleNumber?: string;
}

export class EntityEngine {
  extract(transcript: string): ExtractedEntities {
    const entities: ExtractedEntities = {};
    const text = transcript.trim();
    const lower = text.toLowerCase();

    const quantityMatch = lower.match(/(\d+(?:\.\d+)?)\s*(piece|pcs|pc|kg|nos)?/i);
    if (quantityMatch && this.looksLikeQuantityIntent(lower)) {
      entities.quantity = Number(quantityMatch[1]);
      entities.unit = (quantityMatch[2] ?? 'PCS').toUpperCase();
    }

    const rateMatch = lower.match(/(?:rate|@)?\s*(\d+(?:\.\d+)?)/i);
    if (rateMatch && this.looksLikeRateIntent(lower)) {
      entities.rate = Number(rateMatch[1]);
    }

    const vehicleMatch = text.match(/\b([A-Z]{2}\d{1,2}[A-Z]{1,2}\d{4})\b/i);
    if (vehicleMatch) {
      entities.vehicleNumber = vehicleMatch[1].toUpperCase();
    }

    if (lower.includes('jaipur')) entities.deliveryLocation = 'Jaipur';

    if (!lower.includes('quantity') && !lower.includes('qty') && !lower.includes('rate')) {
      if (!this.looksLikeNumericOnly(lower) && lower.length >= 3 && lower.length <= 80) {
        if (lower.includes('glass') || lower.includes('item') || lower.includes('material')) {
          entities.item = text;
        } else if (!vehicleMatch) {
          entities.customer = text;
        }
      }
    }

    if (lower.includes('balaji')) {
      entities.transporter = 'Balaji';
    }

    return entities;
  }

  private looksLikeNumericOnly(value: string) {
    return /^\d+(?:\.\d+)?$/.test(value);
  }

  private looksLikeQuantityIntent(value: string) {
    return value.includes('quantity') || value.includes('qty') || value.includes('piece') || /^\d+(?:\.\d+)?\s*(piece|pcs|pc|kg|nos)?$/i.test(value);
  }

  private looksLikeRateIntent(value: string) {
    return value.includes('rate') || /^\d+(?:\.\d+)?$/.test(value);
  }
}
