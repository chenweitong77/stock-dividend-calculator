/**
 * HTTP 请求工具类
 * 封装 @ohos.net.http 常用操作
 */
import http from '@ohos.net.http';

/** HTTP Header 项 */
export class HttpHeaderItem {
  key: string = '';
  value: string = '';
}

export class HttpUtil {
  /**
   * GET 请求
   */
  static async get(url: string, headers?: Record<string, string>): Promise<string> {
    const httpRequest = http.createHttp();
    try {
      const headerArray: HttpHeaderItem[] = [];
      if (headers) {
        const keys = Object.keys(headers);
        for (let i = 0; i < keys.length; i++) {
          const k = keys[i];
          const item = new HttpHeaderItem();
          item.key = k;
          item.value = headers[k];
          headerArray.push(item);
        }
      }

      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: headerArray,
        readTimeout: 10000,
        connectTimeout: 10000,
      });

      if (response.responseCode === 200) {
        return (response.result as string) ?? '';
      } else {
        throw new Error('HTTP ' + response.responseCode);
      }
    } finally {
      httpRequest.destroy();
    }
  }
}
