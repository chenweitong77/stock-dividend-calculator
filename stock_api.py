# -*- coding: utf-8 -*-
"""
股票数据接口模块

数据来源：
  - 实时股价：新浪财经 hq.sinajs.cn
  - 分红数据：东方财富 datacenter-web.eastmoney.com
             接口 reportName=RPT_LICO_FN_CPD
"""

import re
import json
import requests
from typing import Optional, List, Dict, Any


class SinaStockAPI:
    """新浪财经股票行情接口"""

    BASE_URL = "https://hq.sinajs.cn/list={prefix}{code}"

    @staticmethod
    def get_price(code: str) -> Optional[Dict[str, Any]]:
        """
        获取股票实时行情

        Args:
            code: 股票代码（6位数字，如 "601318"）

        Returns:
            包含以下字段的字典：
            - name: 股票名称
            - open: 开盘价
            - prev_close: 昨收价
            - current: 当前价
            - high: 今日最高
            - low: 今日最低
            返回 None 表示获取失败
        """
        prefix = "sh" if code.startswith("6") else "sz"
        url = SinaStockAPI.BASE_URL.format(prefix=prefix, code=code)

        headers = {
            "User-Agent": "Mozilla/5.0",
            "Referer": "https://finance.sina.com.cn",
        }

        try:
            resp = requests.get(url, headers=headers, timeout=8)
            resp.encoding = "gbk"
            content = resp.text

            # 解析格式: var hq_str_sh600519="贵州茅台,现价,昨收,开盘价,最高,最低,..."
            match = re.search(r'"([^"]+)"', content)
            if not match:
                return None

            fields = match.group(1).split(",")

            return {
                "name": fields[0].strip() if fields[0] else "",
                "open": float(fields[1]) if fields[1] else 0.0,
                "prev_close": float(fields[2]) if fields[2] else 0.0,
                "current": float(fields[3]) if fields[3] else 0.0,
                "high": float(fields[4]) if fields[4] else 0.0,
                "low": float(fields[5]) if fields[5] else 0.0,
            }
        except Exception:
            return None


class EastMoneyDividendAPI:
    """东方财富分红数据接口"""

    BASE_URL = "https://datacenter-web.eastmoney.com/api/data/v1/get"

    @staticmethod
    def get_dividend_records(code: str, page_size: int = 20) -> List[Dict[str, Any]]:
        """
        获取股票历史分红记录

        Args:
            code: 股票代码（6位数字，如 "601318"）
            page_size: 返回记录数量，默认20条

        Returns:
            分红记录列表，每条记录包含：
            - SECURITY_CODE: 股票代码
            - SECURITY_NAME_ABBR: 股票名称
            - REPORTDATE: 报告日期
            - PAYYEAR: 利润归属年度（如 "2025"）
            - ASSIGNDSCRPT: 分红方案描述（如 "10派16.20元(含税,扣税后14.58元)"）
            - ZXGXL: 东方财富API股息率
            - NOTICE_DATE: 公告日期
            - EITIME: 除权除息日
        """
        params = {
            "reportName": "RPT_LICO_FN_CPD",
            "columns": (
                "SECURITY_CODE,SECURITY_NAME_ABBR,REPORTDATE,"
                "ASSIGNDSCRPT,PAYYEAR,ZXGXL,NOTICE_DATE,EITIME"
            ),
            "filter": f'(SECURITY_CODE="{code}")',
            "pageNumber": 1,
            "pageSize": page_size,
            "source": "WEB",
            "client": "WEB",
        }

        headers = {
            "User-Agent": "Mozilla/5.0",
            "Referer": "https://data.eastmoney.com/",
        }

        try:
            resp = requests.get(
                EastMoneyDividendAPI.BASE_URL,
                params=params,
                headers=headers,
                timeout=10,
            )
            data = resp.json()

            if data.get("success") and data.get("result"):
                return data["result"].get("data", [])
            return []
        except Exception:
            return []

    @staticmethod
    def parse_dividend_per_share(assign_desc: str) -> float:
        """
        解析 ASSIGNDSCRPT 字段，提取每股现金分红

        Args:
            assign_desc: 分红方案描述（如 "10派276.73元(含税,扣税后249.057元)"）

        Returns:
            每股派息金额（元）
            返回 0 表示解析失败或无现金分红

        Example:
            "10派276.73元(含税)" -> 27.673
            "10派16.20元(含税,扣税后14.58元)" -> 1.62
        """
        if not assign_desc:
            return 0.0

        # 匹配格式: "10派276.73元"
        match = re.search(r"(\d+)派([\d.]+)元", assign_desc)
        if match:
            per_count = int(match.group(1))
            total_amount = float(match.group(2))
            return total_amount / per_count

        return 0.0


def get_stock_info(code: str) -> Dict[str, Any]:
    """
    获取股票完整信息（行情 + 分红）

    Args:
        code: 股票代码

    Returns:
        包含 price_info 和 dividend_records 的字典
    """
    price_info = SinaStockAPI.get_price(code)
    dividend_records = EastMoneyDividendAPI.get_dividend_records(code)
    return {
        "price_info": price_info,
        "dividend_records": dividend_records,
    }
