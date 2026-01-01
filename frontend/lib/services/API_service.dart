import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import 'package:http_parser/http_parser.dart';


class ApiService {
  late Dio _dio;
  late PersistCookieJar _cookieJar;
  final String baseUrl = NGROK_HTTP_URL;

  final Completer<void> _initialized = Completer<void>();
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _setupDio();
  }
  PersistCookieJar get cookieJar => _cookieJar;

  void _setupDio() {
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
      requestHeader: true,
      responseHeader: true,
    ));

    _initPersistentCookieJar();
  }

  Future<void> _initPersistentCookieJar() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final String appDocPath = appDocDir.path;
      _cookieJar = PersistCookieJar(storage: FileStorage('$appDocPath/.cookies/'));
      _dio.interceptors.add(CookieManager(_cookieJar));
      _initialized.complete();
      print('ApiService: PersistCookieJar initialized and added to Dio interceptors.');
    } catch (e) {
      _initialized.completeError(e);
      print('Error initializing PersistCookieJar: $e');
    }
  }

  Future<void> ensureInitialized() => _initialized.future;

  Dio get dio => _dio;

  Future<String?> getSessionCookie() async {
    // Ensure the cookie jar has finished initialization
    await ensureInitialized();

    // Load cookies for the base URL (where the login cookie was set)
    final Uri uri = Uri.parse(baseUrl);
    final List<Cookie> cookies = await _cookieJar.loadForRequest(uri);

    if (cookies.isEmpty) {
      print('DEBUG: No cookies found for $baseUrl.');
      return null;
    }

    // Convert the List<Cookie> into the required HTTP header format (e.g., "JSESSIONID=abc; other_cookie=xyz")
    final String cookieString = cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
    print('DEBUG: Retrieved session cookie string: $cookieString');

    // We specifically look for 'JSESSIONID' which is commonly used by Jetty backends for session management
    final sessionCookie = cookies.firstWhere(
            (cookie) => cookie.name == 'JSESSIONID',
        orElse: () => Cookie('dummy', '') // Placeholder if not found
    );

    if (sessionCookie.name == 'dummy') {
      print('DEBUG: JSESSIONID cookie not found');
      return null;
    }

    // Return the session cookie in the correct format for the Cookie header
    // Format: "JSESSIONID=value"
    final cookieHeaderValue = '${sessionCookie.name}=${sessionCookie.value}';
    print('DEBUG: Returning session cookie: $cookieHeaderValue');
    return cookieHeaderValue;
  }
  Future<void> saveUserData({
    required String userId,
    required String username,
    required String email,
    required String publicKeyPem,
    String? privateKeyPem,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    await prefs.setString('username', username);
    await prefs.setString('email', email);
    await prefs.setString('publicKeyPem', publicKeyPem);
    if (privateKeyPem != null) {
      await prefs.setString('privateKeyPem', privateKeyPem);
    }
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('email');
  }

  Future<Map<String, dynamic>> registerUser({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNo,
    required String password,
    required String rePassword,
    String? profileImageBase64,
  }) async {
    try {
      final response = await _dio.post(
        '/register',
        data: {
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'phoneNo': phoneNo,
          'password': password,
          'rePassword': rePassword,
          'profileImageBase64': profileImageBase64,
        },
      );

      return response.data;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
// Add this method to your existing ApiService class in API_service.dart

  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await ensureInitialized(); // Ensure cookies are loaded

      print("DEBUG: Attempting password change");

      final response = await _dio.post(
        '/change-password',
        data: {
          'oldPassword': oldPassword,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
      );

      print("DEBUG: Change password response status: ${response.statusCode}");
      print("DEBUG: Change password response data: ${response.data}");

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else if (response.data is String) {
        try {
          return jsonDecode(response.data) as Map<String, dynamic>;
        } catch (e) {
          print("ERROR: Change password response string is not valid JSON: ${response.data}");
          return {'success': false, 'message': 'Password change failed: Invalid JSON response.'};
        }
      } else {
        print("ERROR: Unexpected change password response type: ${response.data.runtimeType}");
        return {'success': false, 'message': 'Password change failed: Unexpected response format.'};
      }
    } on DioException catch (e) {
      String errorMessage = 'Password change failed: Network error.';
      if (e.response != null) {
        print("DioError Change Password Response Status: ${e.response?.statusCode}");
        print("DioError Change Password Response Data: ${e.response?.data}");
        if (e.response?.data is Map) {
          errorMessage = e.response?.data['message'] ?? errorMessage;
        } else if (e.response?.data is String) {
          try {
            final errorData = jsonDecode(e.response?.data);
            errorMessage = errorData['message'] ?? errorMessage;
          } catch (_) {
            errorMessage = 'Password change failed: ${e.response?.statusCode} - ${e.response?.statusMessage}';
          }
        } else {
          errorMessage = 'Password change failed: ${e.response?.statusCode} - ${e.response?.statusMessage}';
        }
      } else {
        errorMessage = 'Password change failed: ${e.message}';
      }
      return {'success': false, 'message': errorMessage};
    } catch (e) {
      print("Unhandled error during password change: $e");
      return {'success': false, 'message': 'An unexpected error occurred: $e'};
    }
  }
  Future<Map<String, dynamic>> updatePublicKey({
    required int userId,
    required String publicKeyPem,
  }) async {
    try {
      final response = await _dio.put(
        '/public-key',
        data: {
          'userId': userId,
          'publicKeyPem': publicKeyPem,
        },
      );

      print("DEBUG: UpdateKey PUT Response: ${response.data}");
      return response.data;
    } catch (e) {
      return {'success': false, 'message': 'Failed to update key: $e'};
    }
  }

  Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      print("DEBUG: Attempting login with email: $email");
      print("DEBUG: Password length: ${password.length}");

      final response = await _dio.post(
        '/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      print("DEBUG: Login response status: ${response.statusCode}");
      print("DEBUG: Login response data: ${response.data}");

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else if (response.data is String) {
        try {
          return jsonDecode(response.data) as Map<String, dynamic>;
        } catch (e) {
          print("ERROR: Login response string is not valid JSON: ${response.data}");
          return {'success': false, 'message': 'Login failed: Invalid JSON response.'};
        }
      } else {
        print("ERROR: Unexpected Login response type: ${response.data.runtimeType}");
        return {'success': false, 'message': 'Login failed: Unexpected response format.'};
      }
    } on DioException catch (e) {
      String errorMessage = 'Login failed: Network error.';
      if (e.response != null) {
        print("DioError Login Response Status: ${e.response?.statusCode}");
        print("DioError Login Response Data: ${e.response?.data}");
        if (e.response?.data is Map) {
          errorMessage = e.response?.data['message'] ?? errorMessage;
        } else if (e.response?.data is String) {
          try {
            final errorData = jsonDecode(e.response?.data);
            errorMessage = errorData['message'] ?? errorMessage;
          } catch (_) {
            errorMessage = 'Login failed: ${e.response?.statusCode} - ${e.response?.statusMessage}';
          }
        } else {
          errorMessage = 'Login failed: ${e.response?.statusCode} - ${e.response?.statusMessage}';
        }
      } else {
        errorMessage = 'Login failed: ${e.message}';
      }
      return {'success': false, 'message': errorMessage};
    } catch (e) {
      print("Unhandled error during login: $e");
      return {'success': false, 'message': 'An unexpected error occurred: $e'};
    }
  }

// Add these improved methods to your API_service.dart

  Future<Map<String, dynamic>> uploadProfileImageMultipart(File imageFile) async {
    try {
      await ensureInitialized();

      print("DEBUG: Uploading profile image via multipart: ${imageFile.path}");
      print("DEBUG: File size: ${await imageFile.length()} bytes");

      // Verify file exists and is readable
      if (!imageFile.existsSync()) {
        return {'success': false, 'message': 'Image file does not exist'};
      }

      // Create form data with proper filename and content type
      final filename = imageFile.path.split('/').last;
      final extension = filename.split('.').last.toLowerCase();

      String contentType;
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          contentType = 'image/jpeg';
          break;
        case 'png':
          contentType = 'image/png';
          break;
        case 'gif':
          contentType = 'image/gif';
          break;
        case 'webp':
          contentType = 'image/webp';
          break;
        default:
          contentType = 'image/jpeg';
      }

      FormData formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: filename,
          contentType: MediaType.parse(contentType),
        ),
      });

      print("DEBUG: FormData created with filename: $filename, contentType: $contentType");

      final response = await _dio.post(
        '/profile-image',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      print("DEBUG: Multipart upload response status: ${response.statusCode}");
      print("DEBUG: Multipart upload response headers: ${response.headers}");
      print("DEBUG: Multipart upload response data: ${response.data}");

      Map<String, dynamic> result;

      if (response.data is Map<String, dynamic>) {
        result = response.data as Map<String, dynamic>;
      } else if (response.data is String) {
        try {
          result = jsonDecode(response.data) as Map<String, dynamic>;
        } catch (e) {
          print("ERROR: Multipart response string is not valid JSON: ${response.data}");
          result = {'success': false, 'message': 'Invalid response format: ${response.data}'};
        }
      } else {
        print("ERROR: Unexpected multipart response type: ${response.data.runtimeType}");
        result = {'success': false, 'message': 'Unexpected response format'};
      }

      // Check if the upload was successful based on status code
      if (response.statusCode == 200) {
        result['success'] = true;
        result['message'] = result['message'] ?? 'Image uploaded successfully';
      } else {
        result['success'] = false;
        result['message'] = result['message'] ?? 'Upload failed with status ${response.statusCode}';
      }

      return result;

    } on DioException catch (e) {
      print("DioError Multipart Upload Response Status: ${e.response?.statusCode}");
      print("DioError Multipart Upload Response Data: ${e.response?.data}");

      String errorMessage = 'Multipart upload failed: Network error.';
      if (e.response != null) {
        if (e.response?.data is Map) {
          errorMessage = e.response?.data['message'] ?? 'Upload failed with status ${e.response?.statusCode}';
        } else if (e.response?.data is String) {
          try {
            final errorData = jsonDecode(e.response?.data);
            errorMessage = errorData['message'] ?? 'Upload failed with status ${e.response?.statusCode}';
          } catch (_) {
            errorMessage = 'Upload failed: ${e.response?.statusCode} - ${e.response?.statusMessage}';
          }
        } else {
          errorMessage = 'Upload failed: ${e.response?.statusCode} - ${e.response?.statusMessage}';
        }
      } else {
        errorMessage = 'Network error: ${e.message}';
      }
      return {'success': false, 'message': errorMessage};
    } catch (e) {
      print("Unhandled error during multipart upload: $e");
      return {'success': false, 'message': 'An unexpected error occurred: $e'};
    }
  }
// Improved image loading method
  Future<void> loadProfileImageWithRetry(int userId, Function(String?, bool) onComplete) async {
    int maxRetries = 3;
    int currentRetry = 0;

    while (currentRetry < maxRetries) {
      try {
        await ensureInitialized();

        // Add a small delay for subsequent retries
        if (currentRetry > 0) {
          await Future.delayed(Duration(milliseconds: 500 * currentRetry));
        }

        // Construct the profile image URL with cache busting
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final imageUrl = '${_dio.options.baseUrl}/profile-image?userId=$userId&t=$timestamp';

        print("DEBUG: Attempting to load profile image (attempt ${currentRetry + 1}): $imageUrl");

        // Test if the image exists by making a GET request
        final response = await _dio.get(
          '/profile-image',
          queryParameters: {
            'userId': userId.toString(),
            't': timestamp.toString(), // Cache busting
          },
          options: Options(
            responseType: ResponseType.bytes,
            validateStatus: (status) => status! < 500,
            headers: {
              'Cache-Control': 'no-cache',
            },
          ),
        );

        print("DEBUG: Profile image response status: ${response.statusCode}");

        if (response.statusCode == 200) {
          onComplete(imageUrl, false);
          return;
        } else {
          print("DEBUG: Profile image not found (status: ${response.statusCode})");
          if (currentRetry == maxRetries - 1) {
            onComplete(null, false);
          }
        }

      } catch (e) {
        print('Error loading profile image (attempt ${currentRetry + 1}): $e');
        if (currentRetry == maxRetries - 1) {
          onComplete(null, false);
        }
      }

      currentRetry++;
    }
  }

// Method to verify session is still valid
  Future<bool> verifySession() async {
    try {
      await ensureInitialized();

      final response = await _dio.get(
        '/profile-image', // Use a simple endpoint to test session
        queryParameters: {'userId': '0'}, // Invalid user ID should return 404 but not 401
        options: Options(
          validateStatus: (status) => status! < 500,
        ),
      );

      // If we get 401, session is invalid
      return response.statusCode != 401;
    } catch (e) {
      print("Session verification failed: $e");
      return false;
    }
  }
  /// Upload profile image using base64 encoding
  Future<Map<String, dynamic>> uploadProfileImageBase64(String base64Image) async {
    try {
      await ensureInitialized();

      print("DEBUG: Uploading profile image as base64");

      final response = await _dio.post(
        '/profile-image',
        data: {
          'profileImageBase64': base64Image,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      print("DEBUG: Upload image response status: ${response.statusCode}");
      print("DEBUG: Upload image response data: ${response.data}");

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else if (response.data is String) {
        try {
          return jsonDecode(response.data) as Map<String, dynamic>;
        } catch (e) {
          print("ERROR: Upload image response string is not valid JSON: ${response.data}");
          return {'success': false, 'message': 'Upload failed: Invalid JSON response.'};
        }
      } else {
        print("ERROR: Unexpected upload image response type: ${response.data.runtimeType}");
        return {'success': false, 'message': 'Upload failed: Unexpected response format.'};
      }
    } on DioException catch (e) {
      String errorMessage = 'Image upload failed: Network error.';
      if (e.response != null) {
        print("DioError Upload Image Response Status: ${e.response?.statusCode}");
        print("DioError Upload Image Response Data: ${e.response?.data}");
        if (e.response?.data is Map) {
          errorMessage = e.response?.data['message'] ?? errorMessage;
        } else if (e.response?.data is String) {
          try {
            final errorData = jsonDecode(e.response?.data);
            errorMessage = errorData['message'] ?? errorMessage;
          } catch (_) {
            errorMessage = 'Image upload failed: ${e.response?.statusCode} - ${e.response?.statusMessage}';
          }
        } else {
          errorMessage = 'Image upload failed: ${e.response?.statusCode} - ${e.response?.statusMessage}';
        }
      } else {
        errorMessage = 'Image upload failed: ${e.message}';
      }
      return {'success': false, 'message': errorMessage};
    } catch (e) {
      print("Unhandled error during image upload: $e");
      return {'success': false, 'message': 'An unexpected error occurred: $e'};
    }
  }

  /// Delete profile image
  Future<Map<String, dynamic>> deleteProfileImage() async {
    try {
      await ensureInitialized();

      print("DEBUG: Deleting profile image");

      final response = await _dio.delete('/profile-image');

      print("DEBUG: Delete image response status: ${response.statusCode}");
      print("DEBUG: Delete image response data: ${response.data}");

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else if (response.data is String) {
        try {
          return jsonDecode(response.data) as Map<String, dynamic>;
        } catch (e) {
          print("ERROR: Delete image response string is not valid JSON: ${response.data}");
          return {'success': false, 'message': 'Delete failed: Invalid JSON response.'};
        }
      } else {
        print("ERROR: Unexpected delete image response type: ${response.data.runtimeType}");
        return {'success': false, 'message': 'Delete failed: Unexpected response format.'};
      }
    } on DioException catch (e) {
      String errorMessage = 'Image delete failed: Network error.';
      if (e.response != null) {
        print("DioError Delete Image Response Status: ${e.response?.statusCode}");
        print("DioError Delete Image Response Data: ${e.response?.data}");
        if (e.response?.data is Map) {
          errorMessage = e.response?.data['message'] ?? errorMessage;
        } else if (e.response?.data is String) {
          try {
            final errorData = jsonDecode(e.response?.data);
            errorMessage = errorData['message'] ?? errorMessage;
          } catch (_) {
            errorMessage = 'Image delete failed: ${e.response?.statusCode} - ${e.response?.statusMessage}';
          }
        } else {
          errorMessage = 'Image delete failed: ${e.response?.statusCode} - ${e.response?.statusMessage}';
        }
      } else {
        errorMessage = 'Image delete failed: ${e.message}';
      }
      return {'success': false, 'message': errorMessage};
    } catch (e) {
      print("Unhandled error during image delete: $e");
      return {'success': false, 'message': 'An unexpected error occurred: $e'};
    }
  }

  /// Helper method to convert File to base64 string
  Future<String> fileToBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);

      // Determine MIME type based on file extension
      final extension = file.path.split('.').last.toLowerCase();
      String mimeType;
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
        default:
          mimeType = 'image/jpeg'; // default
      }

      return 'data:$mimeType;base64,$base64String';
    } catch (e) {
      print("Error converting file to base64: $e");
      throw Exception('Failed to convert file to base64: $e');
    }
  }
  Future<bool> testSession() async {
    try {
      final response = await _dio.get('/users/online');
      return response.statusCode == 200;
    } catch (e) {
      print("DEBUG: Session test failed: $e");
      return false;
    }
  }
  String getProfileImageUrl(int userId) {
    return '$baseUrl/profile-image?userId=$userId';
  }
  Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('username');
    await prefs.remove('email');
    await prefs.remove('publicKeyPem');
    await prefs.remove('privateKeyPem');
    await _cookieJar.deleteAll();
    print('User data and cookies cleared.');
  }
}
