# P1 Owner Checklist

Yeh checklist Asad ke liye hai (BUILD-03). P1 mein company, sites, mazdoor, rates aur rozana hazri ban gaye hain. Tankhwah aur invoice abhi nahin, woh P2 aur P3 mein hain.

Test APK: `apps/mobile/build/app/outputs/flutter-apk/app-release.apk`. Yeh test build hai. Asal data na daalein.

## 1. Encryption ka saboot (P0 se baqi)

- [ ] **Aur > Data encryption ki jaanch** kholein. Upar **Sab theek** aana chahiye.
- [ ] App poori tarah band kar ke dobara yeh screen kholein. "Data survives reopen" mein rows 10 barh jani chahiye.

## 2. Setup (5 minute)

- [ ] Pehli baar khulne par sirf company ka naam maanga jaye, phir paanch tabs aayen: Aaj, Companies, Labour, Hisaab, Aur.
- [ ] **Companies** mein aik company add karein, phir us mein site. Site mein aam shuru aur khatam waqt, aur break likhein.
- [ ] Usi company mein **Company ka rate** add karein: fi ghanta AED 10.
- [ ] **Labour** mein 10 mazdoor add karein. Har aik mein **Tankhwah ka rate**: fi ghanta AED 8.
- [ ] Aik mazdoor mein **Pichla baqaya** bhar kar dekhein. Tareekh, wajah aur tasdeeq ke baghair save nahin hona chahiye.

## 3. Asal test: 10 mazdoor ki hazri

Time note karein. Target 60 second hai.

- [ ] **Aaj** par **Hazri lagayein** dabayein. Company aur site chunein, waqt khud aa jana chahiye.
- [ ] **Sab ko select** dabayein, phir **Aage**.
- [ ] 8:00 se 20:00, 60 minute break par yeh aana chahiye: **Company se lena hai AED 1,100.00**, **Mazdoor ko dena hai AED 880.00**.
- [ ] Aik mazdoor par click kar ke **Ghair hazir** karein. Total AED 990.00 aur AED 792.00 ho jane chahiye.
- [ ] **Save karein**. **Aaj** par 9 mazdoor, 9 shifts dikhein.
- [ ] Wahi mazdoor usi waqt dobara daalein. Wajah ke baghair save nahin hona chahiye.
- [ ] **Sab manzoor karein** dabayein. Phir aik manzoor shuda row kholein. Ab wajah likhe baghair correction nahin honi chahiye, aur asal row mehfooz rehni chahiye.
- [ ] Internet band kar ke sab dobara karein. Sab kuch chalna chahiye.

Kitne second lage: ______

## 4. Aap ke faislay

- [ ] **Logo aur mazdoor ki photo (D-023):** Yeh T14 mein documents ke saath aayenge. Theek hai?
- [ ] **Raat ki shift ki tareekh (D-024):** Aap ne manzoor kiya tha ke contract is ko badal sakta hai. Abhi contract mein yeh option nahin. Hazri lagate waqt tareekh khud chun sakte hain. Kya yeh kaafi hai?

## 5. Aap ke karne ke kaam (P0 se baqi)

- [ ] Terminal mein `gh auth login` chalayein, taake PR ban sakein aur CI ka nateeja dekha ja sake.
