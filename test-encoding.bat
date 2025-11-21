@echo off
:: Test encoding settings

echo Testing without UTF-8 encoding:
echo 中文测试 - Chinese Test
echo.

echo Now switching to UTF-8 encoding:
chcp 65001 >nul 2>&1
echo 中文测试 - Chinese Test
echo.

echo If you see correct Chinese characters above, UTF-8 encoding is working!
echo.
pause