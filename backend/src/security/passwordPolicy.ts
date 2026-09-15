export function isValidPassword(password: string) {
  return password.length >= 8 &&
    /[A-Z]/.test(password) &&
    /[a-z]/.test(password) &&
    /[0-9]/.test(password) &&
    /[^A-Za-z0-9]/.test(password);
}

export const passwordPolicyMessage =
  'Password must contain at least 8 characters, including uppercase, lowercase, number, and special character.';