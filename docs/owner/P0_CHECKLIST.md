# P0 Owner Checklist

Yeh checklist Asad ke liye hai (BUILD-03). P0 mein abhi app ki screens nahin hain. Is phase ka kaam bunyaad, hisaab ke qawaid aur encryption ka saboot hai.

## 1. Phone par encryption test (5 minute)

Test APK: `apps/mobile/build/app/outputs/flutter-apk/app-release.apk`

- [ ] APK Android phone par install karein. Yeh sirf test build hai, is mein asal data na daalein.
- [ ] App kholein. Upar **ALL PASSED** likha aana chahiye.
- [ ] App poori tarah band karein, phir dobara kholein.
- [ ] "Data survives reopen" ki line mein rows ki tadaad 10 barh jani chahiye. Is se saabit hota hai ke key phone mein mehfooz rehti hai.
- [ ] Agar kahin **FAIL** likha ho to screenshot bhejein.

## 2. Hisaab ke qawaid ki manzoori

Yeh tajweez hain, qanooni rai nahin. Production se pehle accountant bhi inhein dekhega. Har aik par haan ya tabdeeli batayein.

Asad ne 31-10-2026 ko yeh paanchon manzoor kiye.

- [x] **Rounding:** Har hazri line par fils tak half-up. VAT har invoice line par, aur document ka total lines ka majmua.
- [x] **Mahine ka adhoora hisaab:** Koi default nahin. Har contract mein calendar days ya fixed divisor chunna lazmi.
- [x] **Raat ki shift:** Work date shift shuru hone ki tareekh, contract is ko badal sakta hai.
- [x] **Current wage manfi ho:** Posting rok kar review, khud-ba-khud qarz nahin banega.
- [x] **Mahine ke aakhir mein renewal:** Asal tareekh yaad rahe, chhote mahine mein aakhri din.

## 3. Aap ke karne ke kaam

- [ ] Terminal mein `gh auth login` chalayein, taake issues aur PR ban sakein aur CI ka nateeja dekha ja sake.
- [ ] Pilot APK se pehle app ka naam aur application ID final karein. Baad mein badalne par customers ko dobara install karna parega.

## 4. E-invoicing ka khatra

FTA ke 25-10-2026 ke notice ke mutabiq AED 50m se kam revenue wale businesses ko 31-03-2027 tak Accredited Service Provider appoint karna hai, aur 01-07-2027 tak system lagana hai. Der par har mahine ya us ke hisse par AED 5,000 penalty hai.

Hamara PDF invoice e-invoice nahin hai. Tax adviser se poochein ke aap ke customers mein se kaun is ke daire mein aata hai. Provider integration ka faisla public sale se pehle alag se hoga.
