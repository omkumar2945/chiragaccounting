import { Router } from 'express';

import { login, logout, refreshToken, register } from '../controllers/authController.js';
import { AuthRequest, verifyToken } from '../middleware/auth.js';

const router = Router();

router.post('/register', register);
router.post('/login', login);
router.post('/refresh-token', refreshToken);
router.post('/logout', logout);
router.get('/me', verifyToken, (req: AuthRequest, res) => {
  res.json({ user: req.user });
});

export default router;