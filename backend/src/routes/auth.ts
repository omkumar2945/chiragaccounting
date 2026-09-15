import { Router } from 'express';

import {
  changePasswordWithFirebaseOtp,
  forgotPassword,
  importClients,
  listStaff,
  listClients,
  login,
  loginWithFirebasePhone,
  logout,
  refreshToken,
  register,
  resetPassword,
  verifyPasswordResetOtp,
} from '../controllers/authController.js';
import { AuthRequest, isAdmin, verifyToken } from '../middleware/auth.js';

const router = Router();

router.post('/auth/register', register);
router.post('/auth/login', login);
router.post('/auth/firebase-phone', loginWithFirebasePhone);
router.post('/auth/forgot-password', forgotPassword);
router.post('/auth/verify-otp', verifyPasswordResetOtp);
router.post('/auth/reset-password', resetPassword);
router.post('/auth/refresh-token', refreshToken);
router.post('/auth/logout', logout);
router.post('/auth/firebase-password-change', verifyToken, changePasswordWithFirebaseOtp);
router.get('/users/me', verifyToken, (req: AuthRequest, res) => {
  res.json({ user: req.user });
});
router.get('/admin/clients', verifyToken, isAdmin, listClients);
router.get('/admin/staff', verifyToken, isAdmin, listStaff);
router.post('/admin/clients/import', verifyToken, isAdmin, importClients);

export default router;