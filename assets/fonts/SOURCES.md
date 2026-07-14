# 字型來源

- WenKaiTC-Regular.ttf / WenKaiTC-Medium.ttf（權重 700）— 霞鶩文楷 TC
  - 授權：SIL Open Font License 1.1
  - 來源：https://github.com/lxgw/LxgwWenkaiTC（原檔 15MB）
  - 已子集化到遊戲用字（lib/ 原始碼非 ASCII 字元 + ASCII + 常用標點，約 1283 字，
    pyftsubset --layout-features='*' --no-hinting）→ 800KB/檔。
  - 注意：新增的中文字若不在子集內會退回系統字型（排行榜暱稱等動態字串同理）。
    重生成：收集 lib/ 用字 → pyftsubset（詳見 git log 此檔案的引入 commit）。

- Cubic_11.ttf — 俐方體11號（備選，目前未啟用）
  - 授權：SIL Open Font License 1.1
  - 來源：https://github.com/ACh-K/Cubic-11
  - 換用：pubspec fonts 區塊 + my_app.dart fontFamily 改 'Cubic11'。
