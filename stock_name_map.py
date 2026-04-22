# -*- coding: utf-8 -*-
"""
股票名称映射表

用于支持按股票名称搜索股票代码
支持在首次使用时从 akshare 获取完整股票列表

用法:
    from stock_name_map import search_stocks
    results = search_stocks("中国平安")
"""

import unicodedata
from typing import List, Dict


def _normalize(s: str) -> str:
    """
    标准化字符串：使用 NFKC 规范化并转为小写
    处理全角/半角字符的差异
    """
    return unicodedata.normalize('NFKC', s.lower())


def _similarity(a: str, b: str) -> float:
    """
    计算两个字符串的相似度（简单实现：基于公共字符比例）
    """
    if not a or not b:
        return 0.0
    a_set = set(a)
    b_set = set(b)
    intersection = len(a_set & b_set)
    union = len(a_set | b_set)
    return intersection / union if union > 0 else 0.0

# 基础静态映射表（常用股票，网络不稳定时也能搜索）
STOCK_NAME_MAP = {
    # 银行
    "中国平安": "601318",
    "平安": "601318",
    "招商银行": "600036",
    "招商": "600036",
    "兴业银行": "601166",
    "交通银行": "601328",
    "工商银行": "601398",
    "工行": "601398",
    "建设银行": "601939",
    "建行": "601939",
    "中国银行": "601988",
    "中行": "601988",
    "农业银行": "601288",
    "农行": "601288",
    "平安银行": "000001",
    "浦发银行": "600000",
    "民生银行": "600016",

    # 保险
    "中国人寿": "601628",
    "人寿": "601628",
    "新华保险": "601336",
    "新华": "601336",
    "中国太保": "601601",
    "太保": "601601",
    "人保": "601319",

    # 白酒
    "贵州茅台": "600519",
    "茅台": "600519",
    "五粮液": "000858",
    "泸州老窖": "000568",
    "山西汾酒": "600809",
    "汾酒": "600809",
    "洋河股份": "002304",
    "洋河": "002304",

    # 食品饮料
    "伊利股份": "600887",
    "伊利": "600887",
    "海天味业": "603288",
    "海天": "603288",

    # 家电
    "格力电器": "000651",
    "格力": "000651",
    "美的集团": "000333",
    "美的": "000333",
    "海尔智家": "600690",
    "海尔": "600690",

    # 汽车
    "比亚迪": "002594",
    "上汽集团": "600104",
    "上汽": "600104",
    "长城汽车": "601633",
    "长城": "601633",
    "北汽蓝谷": "600733",

    # 新能源
    "宁德时代": "300750",
    "宁德": "300750",
    "隆基绿能": "601012",
    "隆基": "601012",
    "通威股份": "600438",
    "通威": "600438",

    # 医药
    "恒瑞医药": "600276",
    "恒瑞": "600276",
    "迈瑞医疗": "300760",
    "迈瑞": "300760",
    "药明康德": "603259",
    "药明": "603259",
    "爱尔眼科": "300015",
    "爱尔": "300015",
    "智飞生物": "300122",
    "长春高新": "000661",

    # 科技/互联网
    "中兴通讯": "000063",
    "中兴": "000063",
    "海康威视": "002415",
    "海康": "002415",
    "京东方A": "000725",
    "京东方": "000725",
    "立讯精密": "002475",
    "立讯": "002475",
    "歌尔股份": "002241",
    "歌尔": "002241",

    # 房地产
    "万科A": "000002",
    "万科": "000002",
    "保利发展": "600048",
    "保利": "600048",
    "招商蛇口": "001979",
    "金地集团": "600383",

    # 中字头
    "中国石油": "601857",
    "中石油": "601857",
    "中国石化": "600028",
    "中石化": "600028",
    "中国建筑": "601668",
    "中国中铁": "601390",
    "中国铁建": "601186",
    "中国交建": "601800",
    "中国神华": "601088",
    "神华": "601088",
    "中国联通": "600050",
    "中国重工": "601989",
    "中国核电": "601985",
    "中国电建": "601669",

    # 其他
    "长江电力": "600900",
    "中远海控": "601919",
    "海控": "601919",
    "顺丰控股": "002352",
    "顺丰": "002352",
    "圆通速递": "600233",
    "韵达股份": "002120",
    "万华化学": "600309",
    "万华": "600309",
    "三一重工": "600031",
    "三一": "600031",
    "中联重科": "000157",
    "中联": "000157",
    "海螺水泥": "600585",
    "海螺": "600585",
    "东方财富": "300059",
    "东财": "300059",
    "同花顺": "300033",
    "光大证券": "601788",
    "中信证券": "600030",
    "中信建投": "601066",
    "华泰证券": "601688",

    # 港股/美股
    "阿里巴巴": "9988",
    "阿里": "9988",
    "腾讯": "0700",
    "京东": "9618",
    "美团": "3690",
    "小米": "1810",
    "百度": "9888",
    "网易": "9999",
}

# 全量股票缓存（从 akshare 获取）
_full_stock_map: Dict[str, str] = {}  # 原始 name -> code
_full_stock_map_normalized: Dict[str, str] = {}  # 规范化 name -> code
_cache_loaded = False
_cache_loading = False  # 是否正在加载中
_cache_load_lock = False  # 加载锁，防止并发


def _load_full_stock_list() -> None:
    """从 akshare 加载完整股票列表"""
    global _full_stock_map, _full_stock_map_normalized, _cache_loaded, _cache_loading, _cache_load_lock

    # 如果已经加载完成，直接返回
    if _cache_loaded:
        return

    # 如果 map 已经有数据（可能是 Flask 重启后），直接标记已加载
    if _full_stock_map:
        print(f"[INFO] 股票数据已存在 ({len(_full_stock_map)} 条)，跳过加载")
        _cache_loaded = True
        return

    # 如果已经有其他线程在加载，等待完成
    if _cache_load_lock:
        _wait_for_stock_list(timeout=60.0)
        return

    # 获取锁
    _cache_load_lock = True
    _cache_loading = True

    try:
        # 双重检查（获取锁后再次确认）
        if _cache_loaded:
            return

        import akshare as ak
        print("[INFO] 正在从 akshare 加载完整股票列表...")
        df = ak.stock_info_a_code_name()
        for _, row in df.iterrows():
            code = str(row['code']).strip()
            name = str(row['name']).strip()
            if code and name and len(code) == 6:
                _full_stock_map[name] = code
                _full_stock_map[code] = code  # 代码也加入映射
                # 同时存储规范化的映射
                normalized_name = _normalize(name)
                if normalized_name not in _full_stock_map_normalized:
                    _full_stock_map_normalized[normalized_name] = code
                _full_stock_map_normalized[code] = code
        print(f"[INFO] 已加载 {len(_full_stock_map)} 条股票数据")
        _cache_loaded = True
    except Exception as e:
        print(f"[WARN] 从 akshare 加载股票列表失败: {e}")
    finally:
        _cache_loading = False
        _cache_load_lock = False


def _wait_for_stock_list(timeout: float = 60.0) -> bool:
    """等待股票列表加载完成"""
    import time
    start = time.time()
    while _cache_loading:
        if time.time() - start > timeout:
            return False
        time.sleep(0.5)
    return True


def search_stocks(keyword: str) -> List[Dict[str, str]]:
    """
    搜索股票（按名称或代码）

    Args:
        keyword: 股票名称或代码

    Returns:
        匹配的股票列表，每项包含 code, name, market
    """
    if not keyword:
        return []

    # 规范化搜索词
    keyword_normalized = _normalize(keyword)
    results = []
    seen_codes = set()

    # 先从静态映射表搜索
    for name, code in STOCK_NAME_MAP.items():
        name_normalized = _normalize(name)
        if (keyword_normalized in name_normalized or
            name_normalized in keyword_normalized or
            keyword_normalized == code.lower()):
            if code not in seen_codes:
                seen_codes.add(code)
                results.append({
                    'code': code,
                    'name': name,
                    'market': 'sh' if code.startswith(('6', '5')) else 'sz'
                })
            if len(results) >= 5:
                break

    # 如果静态表没找到，尝试从全量列表搜索
    if len(results) < 5:
        # 触发后台加载（如果还没开始）
        _load_full_stock_list()

        # 等待加载完成（最多等15秒）
        _wait_for_stock_list(timeout=15.0)

        # 首先尝试精确匹配（规范化后）
        for normalized_name, code in _full_stock_map_normalized.items():
            if (keyword_normalized in normalized_name or
                normalized_name in keyword_normalized or
                keyword_normalized == code.lower()):
                if code not in seen_codes and len(code) == 6:
                    seen_codes.add(code)
                    # 找到匹配的原始 name
                    original_name = None
                    for oname, ocode in _full_stock_map.items():
                        if ocode == code and _normalize(oname) == normalized_name:
                            original_name = oname
                            break
                    if original_name is None:
                        original_name = normalized_name  # fallback
                    results.append({
                        'code': code,
                        'name': original_name,
                        'market': 'sh' if code.startswith(('6', '5')) else 'sz'
                    })
                if len(results) >= 10:
                    break

        # 如果还是没找到，使用相似度匹配作为后备
        if not results:
            best_matches = []
            for normalized_name, code in _full_stock_map_normalized.items():
                if len(code) != 6:
                    continue
                # 计算相似度
                sim = _similarity(keyword_normalized, normalized_name)
                if sim > 0.5:  # 相似度阈值
                    best_matches.append((sim, code, normalized_name))
            # 按相似度排序
            best_matches.sort(reverse=True)
            for sim, code, normalized_name in best_matches[:5]:
                if code not in seen_codes:
                    seen_codes.add(code)
                    original_name = None
                    for oname, ocode in _full_stock_map.items():
                        if ocode == code and _normalize(oname) == normalized_name:
                            original_name = oname
                            break
                    if original_name is None:
                        original_name = normalized_name
                    results.append({
                        'code': code,
                        'name': original_name,
                        'market': 'sh' if code.startswith(('6', '5')) else 'sz'
                    })

    return results