enum Permission {
  // User Management
  createUser,
  readUser,
  updateUser,
  deleteUser,
  listUsers,
  
  // Property Management
  createProperty,
  readProperty,
  updateProperty,
  deleteProperty,
  listProperties,
  
  // Car Management
  createCar,
  readCar,
  updateCar,
  deleteCar,
  listCars,
  
  // Media Management
  uploadMedia,
  deleteMedia,
  viewMedia,
  
  // Review Management
  createReview,
  readReview,
  updateReview,
  deleteReview,
  listReviews,
  
  // Message Management
  sendMessage,
  readMessage,
  deleteMessage,
  listMessages,
  
  // Notification Management
  sendNotification,
  readNotification,
  deleteNotification,
  listNotifications,
  
  // Report Management
  createReport,
  readReport,
  updateReport,
  deleteReport,
  listReports,
  
  // Settings Management
  updateSettings,
  readSettings,
  
  // Analytics Access
  viewAnalytics,
  exportAnalytics,
  
  // System Management
  manageSystem,
  viewLogs,
  clearCache,
}

class Role {
  final String name;
  final Set<Permission> permissions;

  const Role({
    required this.name,
    required this.permissions,
  });
}

class Roles {
  static const admin = Role(
    name: 'Admin',
    permissions: {
      Permission.createUser,
      Permission.readUser,
      Permission.updateUser,
      Permission.deleteUser,
      Permission.listUsers,
      Permission.createProperty,
      Permission.readProperty,
      Permission.updateProperty,
      Permission.deleteProperty,
      Permission.listProperties,
      Permission.createCar,
      Permission.readCar,
      Permission.updateCar,
      Permission.deleteCar,
      Permission.listCars,
      Permission.uploadMedia,
      Permission.deleteMedia,
      Permission.viewMedia,
      Permission.createReview,
      Permission.readReview,
      Permission.updateReview,
      Permission.deleteReview,
      Permission.listReviews,
      Permission.sendMessage,
      Permission.readMessage,
      Permission.deleteMessage,
      Permission.listMessages,
      Permission.sendNotification,
      Permission.readNotification,
      Permission.deleteNotification,
      Permission.listNotifications,
      Permission.createReport,
      Permission.readReport,
      Permission.updateReport,
      Permission.deleteReport,
      Permission.listReports,
      Permission.updateSettings,
      Permission.readSettings,
      Permission.viewAnalytics,
      Permission.exportAnalytics,
      Permission.manageSystem,
      Permission.viewLogs,
      Permission.clearCache,
    },
  );

  static const moderator = Role(
    name: 'Moderator',
    permissions: {
      Permission.readUser,
      Permission.listUsers,
      Permission.readProperty,
      Permission.updateProperty,
      Permission.listProperties,
      Permission.readCar,
      Permission.updateCar,
      Permission.listCars,
      Permission.viewMedia,
      Permission.readReview,
      Permission.updateReview,
      Permission.deleteReview,
      Permission.listReviews,
      Permission.readMessage,
      Permission.listMessages,
      Permission.readNotification,
      Permission.listNotifications,
      Permission.createReport,
      Permission.readReport,
      Permission.listReports,
      Permission.readSettings,
      Permission.viewAnalytics,
      Permission.viewLogs,
    },
  );

  static const agent = Role(
    name: 'Agent',
    permissions: {
      Permission.readUser,
      Permission.createProperty,
      Permission.readProperty,
      Permission.updateProperty,
      Permission.listProperties,
      Permission.createCar,
      Permission.readCar,
      Permission.updateCar,
      Permission.listCars,
      Permission.uploadMedia,
      Permission.viewMedia,
      Permission.readReview,
      Permission.listReviews,
      Permission.sendMessage,
      Permission.readMessage,
      Permission.listMessages,
      Permission.readNotification,
      Permission.listNotifications,
      Permission.readSettings,
    },
  );

  static const user = Role(
    name: 'User',
    permissions: {
      Permission.readProperty,
      Permission.listProperties,
      Permission.readCar,
      Permission.listCars,
      Permission.viewMedia,
      Permission.createReview,
      Permission.readReview,
      Permission.listReviews,
      Permission.sendMessage,
      Permission.readMessage,
      Permission.listMessages,
      Permission.readNotification,
      Permission.listNotifications,
      Permission.createReport,
      Permission.readSettings,
    },
  );
}

class PermissionManager {
  static final PermissionManager _instance = PermissionManager._internal();
  factory PermissionManager() => _instance;
  PermissionManager._internal();

  Role? _currentUserRole;

  void setUserRole(Role role) {
    _currentUserRole = role;
  }

  bool hasPermission(Permission permission) {
    return _currentUserRole?.permissions.contains(permission) ?? false;
  }

  bool hasAllPermissions(List<Permission> permissions) {
    return _currentUserRole?.permissions.containsAll(permissions) ?? false;
  }

  bool hasAnyPermission(List<Permission> permissions) {
    return permissions.any((permission) => hasPermission(permission));
  }

  List<Permission> getAllPermissions() {
    return Permission.values.toList();
  }

  List<Permission> getCurrentUserPermissions() {
    return _currentUserRole?.permissions.toList() ?? [];
  }

  bool isAdmin() {
    return _currentUserRole == Roles.admin;
  }

  bool isModerator() {
    return _currentUserRole == Roles.moderator;
  }

  bool isAgent() {
    return _currentUserRole == Roles.agent;
  }

  bool isUser() {
    return _currentUserRole == Roles.user;
  }
} 