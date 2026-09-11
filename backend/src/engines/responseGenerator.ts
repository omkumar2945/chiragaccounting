import { CommandStatus } from '../domain/enums.js';

export class ResponseGenerator {
  greeting(): string {
    return 'Namaste! Bataiye, main aapki kya help kar sakta hoon?';
  }

  messageForStatus(status: CommandStatus, fallback: string): string {
    if (fallback.trim().length > 0) return fallback;
    switch (status) {
      case 'needs_input':
        return 'Aur detail batayiye.';
      case 'awaiting_confirmation':
        return 'Confirm kar dein?';
      case 'success':
        return 'Bilkul, kaam ho gaya.';
      case 'failed':
        return 'Maaf kijiye, is request mein issue aaya.';
      default:
        return fallback;
    }
  }
}

