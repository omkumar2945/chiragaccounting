import { randomInt } from 'node:crypto';

const uppercase = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const lowercase = 'abcdefghijkmnopqrstuvwxyz';
const digits = '23456789';
const symbols = '@#%';
const allCharacters = `${uppercase}${lowercase}${digits}${symbols}`;

export function generateTemporaryPassword(length = 12) {
  if (!Number.isSafeInteger(length) || length < 8) {
    throw new Error('Temporary password length must be at least eight characters.');
  }

  const characters = [uppercase, lowercase, digits, symbols].map(
    (alphabet) => alphabet[randomInt(alphabet.length)],
  );
  while (characters.length < length) {
    characters.push(allCharacters[randomInt(allCharacters.length)]);
  }
  for (let index = characters.length - 1; index > 0; index--) {
    const swapIndex = randomInt(index + 1);
    [characters[index], characters[swapIndex]] = [
      characters[swapIndex],
      characters[index],
    ];
  }
  return characters.join('');
}