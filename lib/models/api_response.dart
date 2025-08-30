class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? errorMessage;

  ApiResponse({
    required this.success,
    this.data,
    this.errorMessage,
  });
} 