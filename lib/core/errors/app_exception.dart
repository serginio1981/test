sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'No internet connection']);
}

class ApiException extends AppException {
  const ApiException(super.message, {this.statusCode});
  final int? statusCode;
}

class AudioRecordingException extends AppException {
  const AudioRecordingException([super.message = 'Failed to record audio']);
}

class PermissionDeniedException extends AppException {
  const PermissionDeniedException([super.message = 'Permission denied']);
}

class StorageException extends AppException {
  const StorageException([super.message = 'Storage error']);
}

class IdentificationException extends AppException {
  const IdentificationException(
      [super.message = 'Could not identify bird sound']);
}
