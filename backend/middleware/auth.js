const jwt = require('jsonwebtoken');

function authenticate(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Accès refusé. Jeton d\'authentification manquant.' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Jeton expiré ou invalide.' });
  }
}

function requireAdmin(req, res, next) {
  if (!req.user) {
    return res.status(401).json({ error: 'Non authentifié.' });
  }
  const role = (req.user.role || '').toLowerCase();
  if (role !== 'admin' && role !== 'administrateur' && role !== 'doctor' && role !== 'médecin') {
    return res.status(403).json({ error: 'Accès réservé aux administrateurs ou médecins.' });
  }
  next();
}

function authenticatePatient(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Accès espace patient refusé. Jeton manquant.' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (decoded.role !== 'patient' || !decoded.patientId) {
      return res.status(403).json({ error: 'Jeton patient invalide.' });
    }
    req.patient = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Session patient expirée. Veuillez vous reconnecter.' });
  }
}

function allowAnyAuth(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Jeton manquant.' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (decoded.role === 'patient') {
      req.patient = decoded;
    } else {
      req.user = decoded;
    }
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Jeton expiré ou invalide.' });
  }
}

module.exports = {
  authenticate,
  requireAdmin,
  authenticatePatient,
  allowAnyAuth,
};

