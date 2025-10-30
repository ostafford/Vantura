export interface DisplayConfig {
  locale: string;
  currency: string;
}

export function getDisplayLocaleAndCurrency(): DisplayConfig {
  const locale = typeof navigator !== 'undefined' && navigator.language ? navigator.language : 'en-US';
  const currency = (import.meta as any)?.env?.VITE_APP_CURRENCY || 'USD';
  return { locale, currency };
}

export function formatAmount(value: number, opts?: { currency?: string; locale?: string }): string {
  const { locale, currency } = { ...getDisplayLocaleAndCurrency(), ...(opts || {}) };
  try {
    return new Intl.NumberFormat(locale, { style: 'currency', currency }).format(value ?? 0);
  } catch {
    return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(value ?? 0);
  }
}

export function formatDate(date: Date | string, opts?: { locale?: string; options?: Intl.DateTimeFormatOptions }): string {
  const locale = opts?.locale || getDisplayLocaleAndCurrency().locale;
  const d = typeof date === 'string' ? new Date(date) : date;
  const options: Intl.DateTimeFormatOptions = opts?.options || { year: 'numeric', month: 'short', day: '2-digit' };
  try {
    return new Intl.DateTimeFormat(locale, options).format(d);
  } catch {
    return new Intl.DateTimeFormat('en-US', options).format(d);
  }
}

export function formatIsoDate(date: Date | string): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}


