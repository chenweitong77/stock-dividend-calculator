/**
 * HTTP 请求工具类
 * 封装 @ohos.net.http 常用操作
 */
import http from '@ohos.net.http';

export class HttpUtil {
  /**
   * GET 请求
   */
  static async get(url: string, headers?: Record<string, string>): Promise<string> {
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: headers ? Object.entries(headers).map(([k, v]) => ({ key: k, value: v })) : [],
        readTimeout: 10000,
        connectTimeout: 10000,
      });

      if (response.responseCode === 200) {
        return (response.result as string) ?? '';
      } else {
        throw new Error(`HTTP ${response.responseCode}`);
      }
    } finally {
      httpRequest.destroy();
    }
  }
}
