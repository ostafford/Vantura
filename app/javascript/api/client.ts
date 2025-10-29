/**
 * Centralized API client for all API requests
 * Handles CSRF tokens, error parsing, and standard response formatting
 */

import type { ApiResponse, ApiError } from '../types/api';

/**
 * Get CSRF token from meta tag
 */
function getCSRFToken(): string | null {
  const meta = document.querySelector('meta[name="csrf-token"]');
  return meta?.getAttribute('content') || null;
}

/**
 * Parse error response from API
 */
async function parseError(response: Response): Promise<ApiError> {
  let error: ApiError;

  try {
    const data = await response.json();
    if (data.error) {
      error = data as ApiError;
    } else {
      // Fallback for non-standard error responses
      error = {
        error: {
          code: 'unknown_error',
          message: data.message || `Server error: ${response.status}`,
          details: data
        }
      };
    }
  } catch {
    // Failed to parse JSON, return generic error
    error = {
      error: {
        code: 'parse_error',
        message: `Server error: ${response.status} ${response.statusText}`,
        details: {}
      }
    };
  }

  return error;
}

/**
 * Request options for API calls
 */
export interface ApiRequestOptions extends RequestInit {
  params?: Record<string, string | number | boolean | null | undefined>;
  skipCSRF?: boolean;
}

/**
 * Make a request to the API
 * @param url - API endpoint URL
 * @param options - Fetch options and custom parameters
 * @returns Promise resolving to typed API response
 */
export async function apiRequest<T>(
  url: string,
  options: ApiRequestOptions = {}
): Promise<ApiResponse<T>> {
  const { params, skipCSRF = false, ...fetchOptions } = options;

  // Build URL with query parameters
  let finalUrl = url;
  if (params) {
    const searchParams = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
      if (value != null && value !== '') {
        searchParams.append(key, String(value));
      }
    });
    const queryString = searchParams.toString();
    if (queryString) {
      finalUrl = `${url}${url.includes('?') ? '&' : '?'}${queryString}`;
    }
  }

  // Get CSRF token if not skipped (for same-origin requests)
  const csrfToken = skipCSRF ? null : getCSRFToken();

  // Build headers
  const headers = new Headers(fetchOptions.headers);

  // Set Content-Type for JSON requests
  if (!headers.has('Content-Type') && (fetchOptions.method === 'POST' || fetchOptions.method === 'PATCH' || fetchOptions.method === 'PUT')) {
    headers.set('Content-Type', 'application/json');
  }

  // Set Accept header
  if (!headers.has('Accept')) {
    headers.set('Accept', 'application/json');
  }

  // Add CSRF token if available
  if (csrfToken && (fetchOptions.method === 'POST' || fetchOptions.method === 'PATCH' || fetchOptions.method === 'PUT' || fetchOptions.method === 'DELETE')) {
    headers.set('X-CSRF-Token', csrfToken);
  }

  // Build fetch options
  const fetchConfig: RequestInit = {
    ...fetchOptions,
    headers,
    credentials: 'same-origin' // Include session cookies
  };

  // Make request
  const response = await fetch(finalUrl, fetchConfig);

  // Handle non-2xx responses
  if (!response.ok) {
    const error = await parseError(response);
    throw error;
  }

  // Parse successful response
  const data = await response.json();

  // Validate response structure
  if (!data.data && !data.error) {
    // Response doesn't match expected structure, wrap it
    return {
      data: data as T,
      meta: {
        timestamp: new Date().toISOString(),
        version: 'v1'
      }
    };
  }

  return data as ApiResponse<T>;
}

/**
 * GET request helper
 */
export async function apiGet<T>(url: string, params?: ApiRequestOptions['params']): Promise<ApiResponse<T>> {
  return apiRequest<T>(url, { method: 'GET', params });
}

/**
 * POST request helper
 */
export async function apiPost<T>(url: string, body?: unknown, params?: ApiRequestOptions['params']): Promise<ApiResponse<T>> {
  return apiRequest<T>(url, {
    method: 'POST',
    body: body ? JSON.stringify(body) : undefined,
    params
  });
}

/**
 * PATCH request helper
 */
export async function apiPatch<T>(url: string, body?: unknown, params?: ApiRequestOptions['params']): Promise<ApiResponse<T>> {
  return apiRequest<T>(url, {
    method: 'PATCH',
    body: body ? JSON.stringify(body) : undefined,
    params
  });
}

/**
 * PUT request helper
 */
export async function apiPut<T>(url: string, body?: unknown, params?: ApiRequestOptions['params']): Promise<ApiResponse<T>> {
  return apiRequest<T>(url, {
    method: 'PUT',
    body: body ? JSON.stringify(body) : undefined,
    params
  });
}

/**
 * DELETE request helper
 */
export async function apiDelete<T>(url: string, params?: ApiRequestOptions['params']): Promise<ApiResponse<T>> {
  return apiRequest<T>(url, { method: 'DELETE', params });
}

