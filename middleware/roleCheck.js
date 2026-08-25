const roleCheck = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Authentication required' });
    }
    const userRole = req.user.role || 'student';
    if (['owner', 'superadmin', 'admin', 'branch_manager'].includes(userRole) || roles.includes(userRole)) {
      return next();
    }
    return res.status(403).json({ success: false, message: `User role ${userRole} is not authorized to access this route` });
  };
};

module.exports = { roleCheck };
