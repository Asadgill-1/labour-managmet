**PRODUCT REQUIREMENTS DOCUMENT**

# Labour Supply Management App

**Android customer app + platform-owner web dashboard**

Roman Urdu  |  Version 1.0  |  30-10-2026

**Tayyar baraye Asad Gill**

Tafseeli build specification aur Claude / GitHub handover.

Is PRD mein roz ki hazri, hourly/shift/monthly rates, salary carry-forward, advances, timesheets, invoices, VAT, har-document letterhead, free/paid plans aur manager sharing aik musalsal workflow mein hain.

App malik ka alag web dashboard customers, apni subscription revenue, product numbers, errors aur support ka overview dega. Customer company ka payroll dashboard is se alag hai.

Bunyadi design: local-first operational data, chhota online control backend, aur paid multi-device sync. Bilkul zero-cloud system tamam requested features ko aik saath poora nahin karta.

Haalat: requirements aur handover tayyar hain. App ki coding, testing, GitHub deployment aur production release abhi nahin huay. Prices, plan limits aur performance targets tajweez hain; approved ya measured results nahin.

**166 REQUIREMENTS  /  26 BUILD TASKS  /  48 TEST SCENARIOS**

## Is document ka naqsha

**01**  Maqsad, scope aur teen alag qisam ke owner

**02**  Asaan UI/UX aur screen ki tarteeb

**03**  Account, login aur company isolation

**04**  Apni company, clients, sites aur workers

**05**  Rozana attendance aur bulk entry

**06**  Rates, breaks aur calculation engine

**07**  Payroll, advances, deductions aur carry-forward

**08**  Client timesheets: daily detail aur approval

**09**  Invoices, VAT aur client receivables

**10**  Har document par letterhead, save aur WhatsApp

**11**  Tenant reports aur month-end closing

**12**  Free aur paid plans: launch ki tajweez

**13**  Bank transfer, subscription aur license

**14**  Local-first architecture aur kharch ki haqeeqat

**15**  Manager access aur sync rules

**16**  Encryption, backup, restore aur device change

**17**  App malik ka alag web dashboard

**18**  Investor/sale numbers: definitions aur evidence

**19**  Monitoring, alerts aur maslay ki recovery

**20**  Data model aur trusted transaction boundaries

**21**  Build phases aur release gates

**22**  Claude aur GitHub: kuch miss na hone ka nizam

**23**  Acceptance tests aur final owner checklist

**24**  Official sources aur verification notes

Pehle chapters rozmarra business workflow ke hain. Chapters 12-19 paid plans, technical model aur aapke platform-owner dashboard ko explain karte hain. Chapters 20-23 implementation aur acceptance hain; chapter 24 official source notes hai.

## 01 | Maqsad, scope aur teen alag qisam ke owner

App ka maqsad Dubai/UAE ki labour-supply companies ko roz ki hazri, company billing, mazdoor ki tankhwah, advance, katoti, baqaya, timesheet aur invoices aik asaan mobile workflow mein dena hai. User ko accounting ya coding samajhne ki zaroorat na ho.

**Platform Owner:** Asad, yani is software/app ka malik. Is ka alag web dashboard subscriptions, apne customers, apni revenue, product usage, support aur errors dikhaye. Isay labour companies ke confidential payroll ko bila-zaroorat dekhne ka haq na mile.

**Company Owner / Tenant Owner:** Woh labour-supply company jo app istemal karti hai. Is ki company profile, labour, client companies aur hisaab aik alag tenant/workspace mein hon.

**Client Company:** Woh customer jisko labour bheji jati hai. Aik tenant ke chaar clients, chaar alag app-tenant nahin hain. Har client ke kai sites ho sakte hain. Yeh farq database, UI aur reports mein saaf rahe.

**Manager:** Tenant owner ka invited staff member. Apna login, apna phone aur sirf di hui permissions. Owner ka password share karna workflow nahin hoga.

**Scope:** Android pehla platform; aik tenant = aik legal labour-supply company; Roman Urdu aur English interface; AED currency; DD-MM-YYYY display; Asia/Dubai default timezone. Customer-facing documents English mein default hon, Roman Urdu payslip optional. Urdu/Arabic script aur iOS baad ke scope mein alag estimate hon.

**Ghair-shamil initial scope:** Worker self-service login, biometric attendance hardware, live GPS tracking, recruitment, visa processing, end-of-service/gratuity automation, direct WPS submission, full general ledger, corporate-tax filing aur bank integration. Inhein chupke se completed features na maana jaye.

**Product ke natayij:** Pehli usable hazri setup ke baad kam steps mein; pichlay baqaya kabhi gum na hon; customer timesheet aur invoice alag documents hon; do tenants ka data mix na ho; har completed feature ke tests aur saboot hon.

**Requirement IDs:** Har aglay chapter mein diya hua ID implementation, test aur GitHub issue se link hoga. Sirf screen ban jana requirement complete hone ka saboot nahin.

## 02 | Asaan UI/UX aur screen ki tarteeb

**UX-01 — Paanch bottom tabs:** Aaj, Companies, Labour, Hisaab, Aur. Tabs ko har screen par stable rakha jaye. Setup aur daily workflow aik hi data ko use karein; duplicate registers na hon.

| Tab | Andar kya hoga |
| --- | --- |
| Aaj | Aaj ki hazri, bulk entry, kal ki team copy, missing entries, offline/sync indicator |
| Companies | Client list, sites, contracts/rates, client timesheets, invoices aur client statement |
| Labour | Worker list, pay contract, attendance history, advance, katoti, payslips aur baqaya |
| Hisaab | Tankhwah, invoices, paisay mile, paisay diye, expenses aur period closing |
| Aur | Reports, documents, apni company, letterhead, team, backup, plan, help aur settings |

**UX-02 — Onboarding:** Zaban chunein > email/password se account > email verify > apni company ka naam > optional logo/TRN > pehla client/site > pehla worker > pehli hazri. Optional cheezein skip ho sakein; tax invoice se pehle zaroori tax profile complete karwayi jaye.

**UX-03 — Saaf labels:** “Company se lena hai”, “Mazdoor ko dena hai”, “Is mahine ki kamai”, “Pichla baqaya”, “Ab ada kiya”. Sirf debit/credit jaisi accounting istilah na dikhayein. Aik screen par aik main action ho.

**UX-04 — Readability:** Kam az kam 48 logical-pixel touch targets ka design target, readable default text, bari text setting, icon ke saath label, rang ke baghair bhi samajh aane wali status. Error isi field ke paas ho. Amounts ke saath AED ho. Save ke waqt wazeh confirmation aaye.

**UX-05 — Kam typing:** Searchable lists, multi-select, recent site, rate presets, numeric keypad, “sab ko select”, worker-level exception. Kal ki team copy karne par aaj ki attendance khud-ba-khud approved na ho; owner review kare.

**UX-06 — Measurable usability test:** 5 representative non-technical users pe pilot. Setup ke baad 10 workers ki same-rate hazri 60 seconds ke andar, kam az kam 4/5 users bina trainer ke complete karein. Yeh target hai, hasil-shuda result nahin.

**UX-07 — Save ki imaandari:** “Mobile par save”, “Sync baqi”, “Server par save” alag statuses. Internet na ho to spinner rok kar offline kaam jari rahe. Financial error ko silent retry se duplicate entry mein na badlein.

## 03 | Account, login aur company isolation

**AUTH-01:** Email/password primary login ho. Email verification, forgot-password, safe password reset aur rate limiting hon. Google sign-in optional baad mein add ho sakta hai; email/password ki jagah zabardasti nahin.

**AUTH-02:** Signup par immutable tenant ID bane. Naam, phone number ya email-domain match par doosri company ki membership kabhi na mile. Tenant ID server ki verified membership se nikle; request mein bheje huay tenant ID ko akelay trust na karein.

**AUTH-03:** Pehla signup, naya device login, password reset aur invite acceptance online hon. Pehle se authorized device par local PIN/fingerprint se offline unlock ho. PIN/fingerprint email account ka badal nahin, us device ka local lock hai.

**AUTH-04:** Har local database tenant/account boundary mein encrypted ho. Logout/account switch par database handle band, in-memory state clear aur temporary PDF cache remove ho. Same phone par Company B login kare to Company A ka data, thumbnails, notifications ya last-used PDF na dikhe.

**AUTH-05:** Cloud tenant tables par Row Level Security aur membership checks hon. File storage paths, exports, function endpoints aur realtime subscriptions bhi isi boundary ko enforce karein. Sirf screen par button chhupana security nahin. Supabase Auth/RLS is architecture ka aik available option hai. [S02]

**AUTH-06:** App malik ke admin account par MFA lazmi ho. Service-role key, signing private key, SMTP password aur production secrets mobile app ya GitHub mein na hon. Tenant users admin APIs na chala sakein.

**AUTH-07:** Account deletion app aur web dono se request ki ja sake; pehle identity verification aur data export ka raasta ho. Company owner deletion mein tenant ownership/retention ka alag flow ho; manager deletion se company records na mitain. Applicable retention ki wazeh policy banayi jaye. Google Play account-deletion requirements ko release gate rakhein. [S09]

**AUTH-08:** Production email login ke liye real SMTP/domain configuration aur verification/reset delivery test lazmi. Supabase ka default mailer production onboarding ka substitute nahin. [S04]

## 04 | Apni company, clients, sites aur workers

**MASTER-01 — Apni company:** Legal naam, trading naam, address, contact, email, logo, VAT registration status, TRN, invoice prefix, currency, payment terms, bank details aur document footer. Registration status effective date ke saath ho.

**MASTER-02 — Client:** Naam, address, contact person, phone/WhatsApp, email, VAT status, TRN, invoice address, due days, PO/reference, opening receivable aur note. TRN optional jab client VAT-registered na ho. Format-check ko official verification na kaha jaye.

**MASTER-03 — Sites:** Client ke andar site/project naam, location text, contact, active dates aur default shift. Aik client ke mukhtalif sites ke rates alag ho sakein. GPS permission initial requirement nahin.

**MASTER-04 — Worker:** Unique worker code, naam, optional photo/phone, trade, joining date, active/inactive, pay contract, room charge agreement aur verified opening balances. Emirates ID/passport upload default lazmi nahin; sensitive documents ki bila-zaroorat collection na ho.

**MASTER-05 — Opening balances:** “Worker ko purani salary deni hai” aur “Worker ka advance recover karna hai” do alag amounts. Client receivable bhi alag ho. Opening date, source/note aur owner confirmation record ho; opening salary balance ko current-period wage expense dobara na banayein.

**MASTER-06 — Rate cards:** Client se lene ka rate aur worker ko dene ka rate alag. Hour/day/shift/month basis, effective-from date, end date, break rule, included minutes, overtime arrangement aur partial-period rule save ho.

**MASTER-07 — Archive:** History wala worker/client hard-delete na ho. Inactive worker ka baqaya aur payslip accessible rahe. Rehire par same historical identity use ho; name match par auto-merge na ho.

**MASTER-08 — Import:** Paid CSV import mein preview, duplicate warnings, row-wise errors aur safe rollback ho. Import posted payroll/invoices ko bypass na kare. Bulk import se pehle backup prompt ho.

## 05 | Rozana attendance aur bulk entry

**ATT-01 — Flow:** Date > client > site > workers select > shift/time aur rates review > exceptions > preview > Save. 10 workers ke liye 10 dafa same company aur rate dobara enter na karna pare.

**ATT-02 — Entry fields:** Worker, client, site, work date, shift start/end, total minutes, break minutes, break paid/unpaid on client side, break paid/unpaid on payroll side, attendance status, rate snapshot, overtime approval, notes aur created-by.

**ATT-03 — Bulk apply:** Company billing rate selected group par apply ho sakta hai. Worker pay rate har worker ke contract se aaye. Sirf explicit owner-authorized confirmation se group worker pay override ho. Mixed hourly/monthly workers ko aik rate mein silently convert na karein.

**ATT-04 — Exceptions:** Aik worker 2 ghante late, aik half-day, aik overtime aur aik absent ho to group save se pehle us row ko badla ja sake. Save all atomic ho: sab valid rows commit hon, ya errors ke saath clear review; half-saved batch ko success na dikhayein.

**ATT-05 — Duplication:** Same worker, overlapping time aur repeated device request detect hon. Worker aik din do non-overlapping sites par ja sakta hai; sirf date ki bunyaad par valid second job block na ho. Overlap approval reason ke baghair allow na ho.

**ATT-06 — Midnight shift:** End timestamp aglay din ka ho sakta hai. 20:00 se next-day 08:00 = 12 clock hours. Break total duration se zyada nahin. Work date attribution contract policy se ho, silently split na ho.

**ATT-07 — Attendance states:** Draft > submitted > internally approved > payroll/billing linked. Client acknowledgement alag status ho. Client ki approval late hone se worker ki due wage ko automatic zero na karein.

**ATT-08 — Correction:** Draft edit ho sakta hai. Posted/paid/invoiced entry ko overwrite na karein; authorized correction/reversal aur revision trail ho. Jo customer timesheet pehle share hui thi us ka old version mehfooz rahe.

**ATT-09 — Maaloomati summary:** Aaj unique workers, shifts aur worker-days alag labels. Aik worker do shifts kare to unique headcount 1, shift count 2; headcount ko amount calculation ka ambiguous input na banayein.

## 06 | Rates, breaks aur calculation engine

**CALC-01:** Duration integer minutes mein; amounts integer fils ya exact decimal mein. Binary floating-point se payroll/VAT final totals na banayein. AED display 2 decimals; rounding policy aik jagah central ho aur test ho.

**CALC-02 — Hourly:** Clock minutes = end minus start. Client billable minutes = clock minutes minus client-unpaid break. Worker payable minutes = clock minutes minus worker-unpaid break. Dono quantities alag ho sakti hain.

**CALC-03 — Shift/day:** Agreed shift fee ko hourly rate samajh kar multiply na karein. Full shift eligibility, included break, half-day amount, extra time aur partial shift ka explicit contract ho. 12-hour example operational input hai; qanooni working-hour/overtime approval nahin.

**CALC-04 — Monthly:** Worker ka monthly contract aik martaba per payroll period calculate ho; har attendance row par monthly salary dobara na jorein. Joined/left mid-month, unpaid absence, paid leave aur partial period ki policy configured aur effective-dated ho. Calendar-day ya fixed divisor ko “UAE law default” keh kar hard-code na karein.

**CALC-05 — Monthly client billing:** per-worker monthly aur fixed contract monthly alag units hon. Fixed client contract ka fee har worker ki row se multiply na ho. Attendance allocation report alag ho.

**CALC-06 — Rate priority:** Approved entry-specific override > date/site/worker assignment contract > effective client billing contract ya effective worker pay contract. Missing rate par stop-and-review; silent zero na ho. Historical approved row apna rate snapshot use kare.

**CALC-07 — Overtime:** Regular aur overtime minutes alag; commercial client charge aur employee overtime entitlement alag. Contract multiplier aur current legal configuration ko qualified reviewer verify kare. Extra clock hours ko har worker par automatic same multiplier na dein.

| Test misal | Nateeja |
| --- | --- |
| 10 workers; 12 clock hours; 1 unpaid break; client AED 10/hour | 10 x 11 x 10 = AED 1,100, VAT se pehle |
| Wohi 10 workers; payroll AED 8/hour; wohi unpaid break | 10 x 11 x 8 = AED 880 wage cost |
| Is misal ka contribution | AED 220; isay tamam expenses ke baad net profit na kahein |
| Wohi client charge; worker ko agreed full shift AED 70 | 10 x 70 = AED 700; contribution AED 400 |

Yeh arithmetic fixtures hain, labour-law opinion ya real company ke actual figures nahin.

## 07 | Payroll, advances, deductions aur carry-forward

**PAY-01 — Payroll cycle:** Period chunein > approved work/contract review > allowances > approved deductions > preview > owner approve > post > payment record. Draft payroll mein corrections allowed; posted payroll immutable ho.

**PAY-02 — Do alag concepts:** Current month earnings aur purana unpaid salary balance alag hon. Purana balance nayi kamai nahin aur profit report mein dobara wage expense nahin.

**Formula:** Current net wage = gross earnings + allowances - lawful approved deductions - advance recovery. Total salary payable = opening unpaid salary + current net wage + approved adjustments. Closing unpaid salary = total salary payable - allocated salary payments.

**PAY-03 — User ki misal:** September current net AED 1,000; paid AED 500; closing AED 500. October current net AED 1,000; opening AED 500; total payable AED 1,500. October mein zero pay kiya to closing AED 1,500. Kisi mahine rollover limit ki wajah se debt reset na ho.

**PAY-04 — Katoti ki misal:** Opening unpaid AED 500 + current gross AED 1,000 - room AED 200 - advance recovery AED 100 = total payable AED 1,200. Paid AED 600, closing unpaid AED 600. Room/advance yahan sirf approved example inputs hain, har deduction qanoonan allowed hone ka dawa nahin.

**PAY-05 — Advance sub-ledger:** Advance issued, recovered, refunded/adjusted aur outstanding alag ledger ho. AED 300 advance dene par outstanding 300; payroll recovery 100 par outstanding 200. Advance issuance aur salary recovery dono ko wage expense na banayein. Recovery outstanding se zyada na ho.

**PAY-06 — Salary payments:** Amount, date, payment method, reference, receiver aur period allocations. Owner purani salary ke against payment allocate kar sake; default oldest unpaid first, lekin confirmation ke saath. Overpayment ko unexplained negative salary ke bajaye worker advance/credit mein classify karein.

**PAY-07 — Deductions:** Reason, agreement/authorization, amount, effective period aur supporting note. Unauthorized ya configured limit se zyada deduction block/review ho. Negative current wage ko automatic debt bana kar carry na karein.

**PAY-08 — Compliance:** Delayed salary record karna usay legal nahin banata. Due/overdue wages alert hon. Yeh app wage-payment/WPS service nahin; applicable wage obligations aur payment process alag verify hon. [S10]

**PAY-09 — Payslip:** Period earnings, hours/days basis, allowances, itemized deductions, current net, previous unpaid, payments aur closing unpaid clearly separated. Payslip ya signature ko automatic bank payment proof na kahein.

## 08 | Client timesheets: daily detail aur approval

**TS-01:** Client/date range/site chunein aur approved attendance se timesheet banayein. Daily summary aur individual-worker detail do modes hon. Customer ko sirf wahi commercial detail mile jo owner select kare.

**TS-02 — Columns:** Date, site, worker name/code ya agreed trade group, unique persons, shift count jab relevant ho, clock hours, break, billable hours/days/shifts, client rate aur amount. Non-commercial version mein rate/amount hide hon; worker wage rate aur salary deductions kabhi customer timesheet mein na aayein.

**TS-03 — Daily summary:** Same date/site/rate/basis ki rows group hon. Different rates ya hourly/shift/monthly units ko aik ambiguous row mein combine na karein. Totals mein worker-days, unique workers aur billable units ko saaf naam dein.

**TS-04 — Lifecycle:** Draft > internally approved > client ko shared > client accepted/disputed > locked revision. Acceptance evidence note/upload optional ho; uploaded signature ko verified digital signature ka label na dein.

**TS-05 — Invoice source:** Approved eligible items select kar ke invoice ban sake. Single timesheet se aik invoice ya multiple non-overlapping invoices possible hon; billed allocation track ho. Sirf date-range filter se dobara charge karna allowed na ho.

**TS-06 — Revision:** Billed timesheet revise ho to original version preserve rahe aur correction workflow banay. Invoice figure chupke se change na ho. Disputed client hours ko worker payroll se independently review karein.

**TS-07 — Output:** Client ke liye separate timesheet PDF aur separate invoice PDF. “Dono share karein” action dono files attach kare; sirf invoice par attendance ka aik total likhna timesheet requirement poori nahin karta.

**TS-08 — Monthly contracts:** Monthly invoice ke saath attendance evidence rahe, magar timesheet ke daily amounts se monthly flat fee dobara na count ho. Contract unit aur covered dates saaf print hon.

## 09 | Invoices, VAT aur client receivables

**INV-01 — Creation:** Client > service period > site/timesheet items > PO/reference > billing quantities > tax review > preview > issue. Draft ko final legal number na mile. Issuance par unique tenant-specific sequence assign ho.

**INV-02 — Minimum fields:** Supplier legal name/address/TRN where applicable; customer name/address/TRN where applicable; invoice number, issue date, supply date when different, service description, units, quantity, unit price, discount, VAT rate/value, AED totals aur payment terms. Tax Invoice title sirf applicable VAT-registered supplier flow mein. Full invoice template ke liye FTA fields verify hon. [S05]

**INV-03 — VAT:** VAT configuration supplier registration aur supply treatment se chale, sirf customer ka TRN bharne se tax activate na ho. Registered supplier ki standard-rated example default 5% ho; zero-rated, exempt aur out-of-scope alag categories/reasons hon, tax reviewer ki tasdeeq ke saath. [S05]

**INV-04 — Arithmetic:** Exclusive example: AED 1,100 + 5% AED 55 = AED 1,155. Inclusive example: AED 105 / 1.05 = taxable AED 100, VAT AED 5. Line rounding aur document rounding ka aik consistent rule; final tax treatment reviewer approve kare.

**INV-05 — Receipt:** Invoice AED 1,155, received AED 500, outstanding AED 655. Receipt mein date/method/reference aur invoice allocations. Advance client receipt invoice issue hone se pehle ho to unapplied credit rahe; revenue ko cash receipt ke saath dobara na count karein.

**INV-06 — Corrections:** Issued invoice edit/delete ke bajaye credit note/reissue ya controlled cancellation process; original sequence/history preserve. Payment delete ke bajaye authorized reversal. Billed source allocation par unique guard aur idempotency key hon.

**INV-07 — Status:** Draft, issued, partly paid, paid, overdue, credited/cancelled. Past due date + positive outstanding par overdue. Invoice, receipts aur credits se client statement reconcile ho.

**INV-08 — Online/offline numbering:** Local-only tenant ka aik active issuing device sequence own kare. Team tier mein final invoice number online server transaction se mile; offline draft allowed. Do devices ko same final number banane ki ijazat nahin.

**INV-09 — e-Invoicing gate:** PDF ko UAE structured eInvoice na kaha jaye. MOF structured exchange/reporting aur accredited-provider model alag hai. 25-10-2026 FTA notice ke mutabiq in-scope AED 50m+ businesses ka implementation 01-01-2027, below AED 50m ka 01-07-2027 hai. Applicable launch cohort ko ASP integration ke baghair “fully compliant e-invoicing” na bechein. Current scope/deadlines dobara verify hon. [S06] [S07]

## 10 | Har document par letterhead, save aur WhatsApp

**DOC-01 — Aik shared engine:** Invoice, timesheet, payslip, payment receipt, advance receipt, worker statement, client statement, credit note aur tamam exported reports aik company-template engine use karein. Header/footer sirf timesheet ka feature nahin.

**DOC-02 — Free basic identity:** Har plan mein legal company naam, logo when provided, address/contact aur proper footer ho. Paid tier mein apna designed letter-pad header/footer PNG/JPEG upload, crop, scale aur preview ho. Har generated paper par company ki pehchan saaf rahe.

**DOC-03 — Layout:** A4 default, content-safe margins, repeating header/footer on every page, page X of Y, document number, date aur readable table headings. Letterhead image legal text ko cover na kare. Existing pre-printed stationery ke liye “header/footer na print karein” explicit option ho.

**DOC-04 — Images:** Upload type/size validate, aspect ratio preserve aur low-resolution warning. Separate header aur footer ki position adjustable. Signature/stamp optional aur owner-controlled. PDF letterhead import initial requirement nahin; future conversion feature alag task ho.

**DOC-05 — Revision:** Final document ki PDF aur data/template snapshot preserve ho. Baad mein company logo/address badle to purani issued invoice ki exact copy change na ho. Duplicate copy par same number, zaroorat par COPY label ho.

**DOC-06 — Actions:** Preview, phone par PDF save/download, print, Android share sheet aur WhatsApp. WhatsApp installed na ho to share alternatives aayein. Customer khud recipient select aur send confirm kare; automatic message blast ya WhatsApp Business API subscription initial scope nahin.

**DOC-07 — Data safety:** Share se pehle recipient/document summary. Bulk payslips ko workers ke mixed confidential bundle mein default share na karein. Temporary share file time-limited cache mein ho; public unprotected URL default na ho. “Share dialog khula” ko “delivered” status na dikhayein.

**DOC-08 — Tests:** 1-page aur multi-page documents, long names, large amounts, mixed rates, zero VAT, repeated headings, no clipped rows, no blank trailing page. Text searchable/selectable ho; poora document low-resolution screenshot na ho.

## 11 | Tenant reports aur month-end closing

**REP-01 — Reports:** Daily attendance, site-wise deployment, client billed/unbilled work, worker earned/paid/outstanding, advance outstanding, client aging, invoices, receipts, deductions, expenses aur monthly margin. Har report filter/date basis dikhaye.

**REP-02 — Hisaab ki separation:** Worker expense earned wage par; paid wage cash-flow par. VAT collected ko ordinary sales revenue na ginein. Advance paid ko wage expense na samjhein. Client receipts ko issued invoice revenue ke saath dobara na count karein.

**REP-03 — Margin:** Ex-VAT service revenue minus matched worker earnings = labour contribution. Is ke baad transport/room/other allocated business costs hon to separate operating estimate. Full accounting integration ke baghair “audited net profit” na likhein. Salaried worker cost allocation method report par dikhayein.

**REP-04 — Closing:** Missing rates/hazri, unresolved duplicates, unapproved deductions, draft payroll aur unallocated payments warnings. Owner confirmation se period lock ho. Locked period change ke liye owner reason aur dated adjustment/reversal ho.

**REP-05 — Historical integrity:** Archived worker/client ya changed rate ke bawajood purani report stable rahe. Opening balance migration apni source-date ke saath reconcile ho.

**REP-06 — Backup/export:** Basic data export aur encrypted backup sab plans mein. Advanced analysis, saved filters, batch exports aur CSV import paid differentiators ho sakte hain; customer ka apna historical financial data hostage na bane.

**REP-07 — Expenses:** Date/category/amount/payment reference/site allocation optional. Worker se recovered room charge aur company ka actual room expense alag entries hain; report unko label kiye baghair double-net na kare.

**REP-08 — Ledger design:** Immutable payroll postings, invoice postings, payments, allocation aur reversal records balances ka source hon. UI par manually editable “balance” field only opening-balance migration mein ho. Current balance transactions se derive/reconcile ho.

## 12 | Free aur paid plans: launch ki tajweez

Yeh proposed test prices hain, market research ka established result nahin. Pehle 5-10 pilot labour companies ke saath value, willingness to pay aur support cost check karke final karein. Prices ko app code mein hard-code na karein; versioned plan config ho.

| Cheez | Free | Solo | Team |
| --- | --- | --- | --- |
| Tajweez shuda monthly fee | AED 0 | AED 49 | AED 99 |
| Active workers / client companies | 10 / 2 | 100 / 20 | 300 / 50 |
| Seats / active devices | 1 owner / 1 | 1 owner / 1 | 1 owner + 1 manager / 2 |
| Local attendance, wages, advances, arrears | Haan | Haan | Haan |
| Timesheet, invoice, VAT, payslip, share | Haan | Haan | Haan |
| Basic company header/footer | Haan | Haan | Haan |
| Apna designed letterhead | Nahin | Haan | Haan |
| Local backup + basic export | Haan | Haan | Haan |
| Advanced reports / bulk import | Nahin | Haan | Haan |
| Shared data on separate phones | Nahin | Nahin | Haan |
| Managed cloud restore / sync | Nahin | Nahin | Haan, quota ke andar |

**PLAN-01:** Trial 14 din; Team feature trial owner ki clear choice se start ho, khas taur par manager invite par. Free owner flow available rahe. Cloud upload se pehle consent aur “ab shared mode shuru hoga” explanation ho.

**PLAN-02:** Manager trial end par paid Team entitlement na ho to manager access/revocation policy apply; owner ko free/local safe mode mile. Trial ke liye card zaroori nahin; manual plan mein auto-debit ka dawa nahin.

**PLAN-03:** Expiry par data delete, hidden balance ya mandatory ransom export na ho. Existing data read/export/backup accessible rahe. New creation limits, paid customization aur sync restrict hon. Over-limit tenant ko whole workspace read-only kiye baghair plan-compliant workers select/archive karne ka safe workflow mile.

**PLAN-04:** Active worker count ko payroll history se alag karein; archive se debt nahin mitna chahiye. Seat count unique active membership se ho, app installs se nahin.

**PLAN-05:** Optional annual Solo AED 490 / Team AED 990 test offer ho sakta hai. Extra manager AED 25/month sirf successful Team launch ke baad; pehle scale/performance aur cloud-cost check.

**PLAN-06:** Paid upgrade ka sabab real value ho: zyada workers/clients, manager sharing, custom paperwork aur time-saving reports. Core security, correct wage calculation, essential tax fields ya apna data wapas lena paid majboori na ho.

## 13 | Bank transfer, subscription aur license

**BILL-01 — Manual start:** App malik outside-app sales/support ke zariye customer se agreed payment le. Bank mein actual receipt verify kare; screenshot akela proof na ho. Admin dashboard mein tenant, plan, amount, currency, receipt reference, period, received date aur note record kare.

**BILL-02 — Activation:** Verified payment par backend entitlement issue kare. Customer login/refresh kare to paid features activate hon. Zaroorat par short one-time code diya ja sake jo sirf us tenant ke authenticated owner ko redeem ho; static universal password nahin.

**BILL-03 — Safer design:** Code sirf activation reference ho; actual license server-signed ho aur tenant ID, plan, limits, start/end, device allowance, issuer, token ID aur schema version carry kare. Private signing key server par; app ke paas verification key. Redemption rate-limited aur replay-protected ho.

**BILL-04 — Renewals:** Monthly period calendar month-anniversary par; month-end clamp ka documented rule. Early renewal current expiry se extend; expired plan renewal payment/approved start se. Har renewal independent ledger entry. Refund, revoke aur correction reason/audit ke saath.

**BILL-05 — Offline:** Local owner paid entitlement lease ki proposed maximum offline recheck 7 din. Customer ko last verified time aur recheck due dikhayein. Lease end par safe read/export mode rahe, delete nahin. Manager membership checks zyada sakht hon; chapter 15 dekhein.

**BILL-06 — Tampering:** Clock rollback, replay, revoked device aur cloned local files detect/review hon. Offline device par foran revocation ya piracy-proof guarantee nahin di ja sakti. Suspicion par owner ka apna data inaccessible karne ke bajaye online revalidation aur safe mode ho.

**BILL-07 — Play Store policy:** Digital app features/subscriptions ki in-app sale aam tor par Play Billing mangti hai. Consumption-only access paid-outside service ke liye possible hai, magar exact experience/policy review zaroori. UAE ke liye automatic alternative-billing exception assume na karein. Bank-transfer button, payment link ya paid-code sale ko policy bypass na banayein. [S08]

**BILL-08 — Distribution decision:** Pilot ke liye signed Android APK with safe update path, ya policy-reviewed Play consumption-only build. Public launch ka final billing flow Play review ke baad. Google Play Billing integration baad mein possible; entitlement model dono payment sources support kare.

**BILL-09:** Business licensing, invoice/tax treatment aur receiving bank-account permissions user apne relevant advisers/bank se verify kare. Personal account ko commercial collections ke liye universally allowed assume na karein.

## 14 | Local-first architecture aur kharch ki haqeeqat

**ARCH-01 — Mobile:** Flutter/Dart ki Android app; UI, domain calculations aur repositories alag layers. SQLite local relational data store; compatible maintained encryption binding ka feasibility spike pehle ho. Library version/licensing/security support verify karke lockfile commit karein. Flutter offline-first pattern is design ko support karta hai. [S01]

**ARCH-02 — Chhota control backend:** Proposed Supabase Auth + PostgreSQL + restricted server functions. Sirf account, tenant identity, memberships, subscription, payment ledger, minimal telemetry aur support metadata initial cloud scope ho. Workers ki payroll/photos Free/Solo se automatic upload na hon.

**ARCH-03 — App malik web:** React/Next.js + TypeScript proposed responsive admin interface. Phone browser par bhi chale. Customer mobile app ka owner tab nahin; separate admin surface aur privileged permissions hon.

**ARCH-04 — Paid Team:** Tenant ki operational records shared cloud data mein opt-in sync hon aur dono devices par permitted local cache ho. “Data sirf mobile par rehta hai” Team mode ke liye claim na ho. Sync aur online backup alag functions hain.

**ARCH-05 — Cost:** Free service tiers prototyping mein madad kar sakte hain; production ki total cost zero guarantee nahin. Hosting, transactional email, domain, monitoring, storage, egress, store account aur maintenance separate budget items hon. Current Supabase free quotas check karein; low-activity free project pause ho sakta hai. [S03]

**ARCH-06 — Budget controls:** Admin mein monthly limits, per-tenant quota, alert at 70/90 percent of chosen budget, event sampling, attachment compression, retention cleanup aur spend approval. “Unlimited” cloud storage na bechein.

**ARCH-07 — Failure independence:** Backend down hone par authorized local owner attendance, payroll drafts, local PDF aur backup kar sake. New signup, fresh device restore, entitlement change aur team final issuance online boundary hon.

**ARCH-08 — No-code ki wazahat:** Yeh technical software project hai, sirf prompt paste karke guaranteed production-ready no-code app nahin. Claude coding mein madad karega; credentials, account setup, device tests, independent security review aur release approvals insan ko karne honge. Handover ko isi wajah se phases/tests mein divide kiya gaya hai.

## 15 | Manager access aur sync rules

**TEAM-01 — Invite:** Owner email se invite kare, role aur site scope select kare. Manager apna verified login banaye; invite single-use, expiring aur specific tenant se bound ho. Invitation se pehle plan/seat check ho.

**TEAM-02 — Permission presets:** Attendance Manager default mein assigned sites/workers ki hazri dekh/enter kare; wages, client rates, profit, billing, export aur settings default deny. Operations Manager ki extra access owner explicitly de. Owner-only: subscription, team changes, final payroll/invoice, financial reversal aur tenant export.

**TEAM-03 — Payload isolation:** Wage data sirf UI se hide na ho; attendance-only manager ke server response/local database mein wages hi na bhejein. Separate tables/views/column restrictions aur tests hon. RLS row isolation ke saath field-level policy bhi chahiye.

**TEAM-04 — Sync:** Har mutation stable UUID, tenant ID, record version, device ID, idempotency key aur timestamp ke saath outbox mein save ho. Server authorization ke baad ack de. Retry same entry dobara post na kare. Device clock ko conflict ka akela judge na banayein.

**TEAM-05 — Conflicts:** Master-data harmless edits merge ho sakti hain; attendance conflict review queue; financial postings ke liye last-write-wins mana. Owner/manager dono same worker hours badlein to silent overwrite na ho.

**TEAM-06 — Revocation:** Online manager membership revoke hote hi next server request block. Offline limited cache access foran rokna mumkin nahin; proposed manager offline lease 24 hours, phir online authorization required. Previously exported files ko remote recall guarantee na karein. Is limitation ko owner settings mein samjhayein.

**TEAM-07 — Team downgrade:** Confirm all authorized data synced > owner encrypted backup > manager revoke > owner local data preserve > sync disable. Unsynced manager work ko silently drop na karein; owner review/recovery queue ho. Cloud retention notice ke saath policy apply ho.

**TEAM-08 — Pilot safety:** Team trial/public sale tab tak disabled rahe jab tak actual two-device tests, tenant-isolation tests aur recovery tests pass na hon. Sirf demo manager screen ko paid-ready na dikhayein.

## 16 | Encryption, backup, restore aur device change

**DATA-01:** Local database encryption key Android platform ke protected key storage mein ho; hard-coded app secret nahin. PIN se protected key access aur rate limiting ho. Network TLS, secure session handling aur public-storage cache controls hon.

**DATA-02 — Backup bundle:** Encrypted database snapshot, required attachments, template assets, manifest, schema/app version, tenant binding, checksums aur creation time. Backup password/recovery key plaintext bundle mein na ho. Tested standard cryptography use ho, khud ki encryption scheme nahin.

**DATA-03 — Owner warning:** “Phone gum/reset/uninstall aur backup na ho to local data recover nahin ho sakta.” Signup/cloud account ki maujoodgi operational-data backup ki guarantee nahin. Google login dobara karne se local ledger khud-ba-khud wapas nahin aata.

**DATA-04 — Local backup:** Reminder aur manual encrypted off-device export Free mein ho. Sirf same phone ki folder copy ko disaster recovery na kahein. User apni approved storage location choose kare. Successful save aur successful restore alag statuses hon.

**DATA-05 — Restore:** Authorized owner login + recovery secret + tenant identity check > preview > pre-restore backup > integrity/migration check > atomic replacement. Wrong tenant, wrong key, corrupt backup aur incompatible newer schema reject hon. File import ko default merge na banayein.

**DATA-06 — Phone change:** Free/Solo ke liye explicit device transfer; old device authorization revoke, latest backup restore aur invoice sequence continuity check. Stale backup se used invoice numbers dobara issue na hon; sequence reconciliation/review lazmi.

**DATA-07 — Key recovery:** Device-bound encryption aur portable backup encryption alag keys/flows. Password reset se old encrypted local data bina authorized recovery material ke decrypt hone ka jhoota wada na ho.

**DATA-08 — Retention:** Backups, logs, support uploads aur cloud tenant records ki documented policy. Proposed short diagnostic retention 30 din; operational/tax/payroll retention applicable law aur customer controls ke mutabiq. Encryption-at-rest ko full end-to-end encryption na kahein jab server data process kar sakta ho.

## 17 | App malik ka alag web dashboard

Yeh dashboard **Asad, yani software ke malik** ke liye hai. Labour company ka daily business dashboard is se alag hai.

**ADMIN-01 — Navigation:** Overview, Customers, Plans & Payments, Usage, Health & Errors, Support, Releases, Investor Reports aur Settings. Har number ke saath source, date range aur last-updated label ho.

**ADMIN-02 — Customer register:** Tenant ID, business/contact identity, signup date, email verification, current plan, trial/expiry, seat/device count, last online activity, app version, support status aur verified subscription payments. Sensitive payroll/worker documents default nahin.

**ADMIN-03 — Subscription operations:** Payment verify, activate/renew/suspend, grace extension, receipt/refund, plan migration aur internal note. Har admin action actor/time/reason ke saath audit log ho. Finance adjustment original entry overwrite na kare.

**ADMIN-04 — Product funnel:** Store installs, app first-open, registered accounts, created tenants, first worker, first attendance, first invoice, trial start aur paid conversion alag stages. Aik company ke owner + manager = do users magar aik customer tenant.

**ADMIN-05 — Offline visibility:** Customer last synced 5 din pehle ho to “last seen 5 din” dikhayein, current exact active status nahin. Telemetry unavailable/disabled ko zero activity na samjhein. Offline pending event dates aur server receive dates alag hon.

**ADMIN-06 — Health:** Login/reset failures, crash-free sessions, backend latency, sync failures, failed PDFs, backup/restore failures, license refresh errors, queue depth, storage/budget trends aur version adoption. Detail mein redacted technical context ho.

**ADMIN-07 — Support:** App se “Masla report karein” > category > description > optional screenshot after confirmation > ticket number. User ki raza se sanitized diagnostic bundle; full payroll DB automatic nahin. Local-only customer ka record admin ke paas na ho to usay dekhne ka jhoota wada na ho.

**ADMIN-08 — Access:** Platform owner MFA; future support agent read-limited; finance role payments tak; engineer crash metadata tak. Tenant impersonation default disabled. Zaroorat par time-limited consented support session, reason aur audit ho.

## 18 | Investor/sale numbers: definitions aur evidence

**MET-01:** Dashboard fancy totals ke bajaye reproducible data de. Trial accounts ko paid customers, worker records ko app users, aur tenant client invoices ko SaaS revenue na gina jaye.

| Metric | Definition aur source |
| --- | --- |
| Store installs/downloads | Play Console ka exact selected metric; imported report/date/source ke saath |
| Registered users | Verified auth users; owner aur manager dono; tenants se alag |
| Registered customer companies | Unique non-test tenant IDs |
| Active companies | Selected month mein kam az kam aik meaningful event wala unique tenant; reporting coverage saath |
| Paying customers | Defined as-of date par paid service period active, verified non-refunded subscription wale tenants |
| MRR | Active recurring subscription value ko monthly normalize karein; annual fee / 12; taxes/one-off fees alag |
| Cash collected | Bank/store verified receipts minus refunds; cash dates par; MRR se alag |
| Trial-to-paid | Same eligible trial cohort mein paid converters / trial starters; observation window saath |
| Logo churn | Period start paying tenants mein se policy-defined lapsed/cancelled tenants ka ratio |
| ARPA | MRR / paying customer tenants; zero denominator par N/A |

**MET-02 — Manual renewals:** Auto-renew aur manually renewed contract alag labels. Expected renewal, overdue renewal aur confirmed paid month mix na hon. Advance annual cash ko current month ki full recurring revenue na banayein.

**MET-03 — MRR bridge:** Opening MRR + new + expansion + reactivation - contraction - churn = closing MRR. Formula sign-off aur sample reconciliations automated tests mein hon.

**MET-04 — Costs:** Hosting, email, monitoring, storage, support aur payment/platform fees record/import kiye baghair exact gross margin ka dawa na ho. CAC/LTV ke required data missing hon to N/A ya labeled estimate; guessed investor numbers nahin.

**MET-05 — Source of truth:** Play installs ke liye Play reports; auth ke liye backend; receipts ke liye verified payment ledger; activity ke liye deduplicated events. Play exports delayed ho sakte hain, is liye real-time download counter ka wada na ho. [S11]

**MET-06 — Investor pack:** Monthly CSV/PDF metrics, cohort retention, revenue/receipts reconciliation, plan mix, churn reasons, infrastructure costs, issue/release history, methodology version aur data completeness. Customer personal data redact. Yeh valuation guarantee nahin.

**MET-07 — Auditability:** Exclude test/demo/internal tenants using explicit flags. Event UUID dedupe, UTC timestamp, local reporting timezone, correction log aur immutable month-end snapshot. Report rerun ka result methodology version se trace ho.

## 19 | Monitoring, alerts aur maslay ki recovery

**OPS-01 — Privacy-first diagnostics:** Crash/performance SDK ya equivalent se app version, OS, redacted stack, error code, pseudonymous tenant ID aur operation status. Names, salaries, passwords, TRN, full documents aur bank details logs mein na hon. SDK collection configure/test ho; session replay initial version mein off.

**OPS-02 — Telemetry contract:** signup_verified, tenant_created, first_attendance_saved, invoice_issued, trial_started, subscription_activated, sync_failed, pdf_failed, backup_failed. Properties allowlist-based; amounts/worker names analytics events mein nahin.

**OPS-03 — Initial alerts:** Backend consecutive failed health checks; any confirmed cross-tenant exposure; data-corruption event; repeated auth failure spike; sync/PDF errors above configured threshold with minimum sample size. Thresholds operational proposals hon, current performance claims nahin.

**OPS-04 — Severity:** P0 data leak/corruption: immediate incident response. P1 login/sync/billing widely blocked: high priority. P2 limited workflow bug: scheduled fix. P3 cosmetic/request: backlog. Notification email/admin inbox; SMS/WhatsApp automation optional paid provider later.

**OPS-05 — Recovery runbook:** Detect > affected version/tenants identify > contain risky server action > preserve evidence > rollback compatible backend/feature flag > tested fix > communicate > post-incident review. Local financial data ko remote repair command se blindly rewrite na karein.

**OPS-06 — Limits:** Offline phone ki crash report connection ke baad aa sakti hai. Telemetry disabled ya device lost ho to event missing ho sakta hai. Har customer masla automatically detect hoga ya app malik foran fix kar dega, aisa guarantee nahin.

**OPS-07 — Releases:** Staged rollout, crash monitoring, API compatibility, migration versioning, rollback-safe backend aur mandatory update only for serious security incompatibility. Android installed app ki downgrade ko universal rollback solution na maanain.

**OPS-08 — Availability target:** Proposed paid-control-backend 99.5% monthly target after production hosting and monitoring. Initial free-tier pilot par contractual SLA nahin. Target aur measured uptime dashboard mein alag hon.

## 20 | Data model aur trusted transaction boundaries

**MODEL-01 — Local operational groups:** Tenants/profile; clients; sites; workers; effective pay/billing contracts; assignments; attendance batches/entries; payroll runs/lines; advances/recoveries; deductions; salary payments/allocations; timesheet revisions; invoices/lines/source allocations; receipts/allocations; credit notes; expenses; document snapshots; audit events; outbox; backup manifests.

**MODEL-02 — Cloud control groups:** Auth users, tenants, memberships, devices, plans/versions, subscriptions, entitlement leases, verified SaaS payments, activation redemptions, support tickets, diagnostic events, monthly metric snapshots, admin audit aur Play import batches. Team operational tables tenant-isolated cloud scope mein add hon.

**MODEL-03 — Common keys:** UUID primary key, tenant ID, created/updated UTC timestamps, actor ID, record version, source operation ID. Monetary records mein currency aur posting date; effective date ko created-at se alag rakhein.

**MODEL-04 — Constraints:** Cross-tenant foreign key invalid; unique worker code within tenant; unique invoice sequence within tenant; duplicate operation ID rejected; allocation amount document outstanding se zyada na ho; same work-unit ki billed quantity double allocate na ho.

**MODEL-05 — Server-only actions:** Tenant creation/membership changes, trial eligibility, license issue/renew/revoke, verified payment posting, Team final invoice numbering aur platform metrics mutation authenticated privileged functions se. Client app plan flags set kar ke paid role na le sake.

**MODEL-06 — Conceptual API contracts:** Create tenant; invite/accept/revoke member; refresh entitlement; sync push/pull; issue invoice; submit support ticket; ingest minimal events. Har endpoint tenant auth, permission, input schema, idempotency, error codes aur audit requirement define kare. Exact paths developer ADR mein lock kare.

**MODEL-07 — Financial boundary:** Invoice/payroll issue plus ledger posting plus source linkage aik database transaction mein. App crash mid-save par ya to poora commit ya poora rollback. PDF render fail hone se posted financial document duplicate na ho; existing snapshot se render retry ho.

**MODEL-08 — Migration:** Har schema change versioned migration, test fixture aur backup/restore procedure ke saath. Production database reset/drop ko normal upgrade flow na banayein. Fresh install ke saath previous-version upgrade tests bhi hon.

## 21 | Build phases aur release gates

Har phase ka working build, tests aur evidence chahiye. Neechay phases schedule estimates nahin; dependency order hain. Poora scope aik prompt mein “complete app” keh kar shuru na karein.

| Phase | Deliverables | Gate |
| --- | --- | --- |
| P0 | Repo/docs, screen flow, calculation specification, encryption feasibility | Assumptions aur architecture recorded; no hidden scope |
| P1 | Local masters, bulk attendance, rate/break engine | Arithmetic, duplicate, offline save tests pass |
| P2 | Payroll, carry-forward, advances, receipts, ledgers | User examples aur month-close reconciliation pass |
| P3 | Timesheets, invoices, VAT, all-document templates/share | PDF review, duplicate billing, numbering tests pass |
| P4 | Real auth, tenant isolation, backup/restore, Solo entitlement | Two-tenant security, SMTP, device restore tests pass |
| P5 | Platform-owner web dashboard, manual payments, monitoring | Real-source metrics, admin MFA, error-ticket tests pass |
| P6 | Manager trial, permission scope, paid sync | Two-device conflict/revoke/restore tests pass |
| P7 | Security/compliance review, pilot fixes, release artifacts | Store/billing/privacy gates and full regression pass |

**BUILD-01:** Auth/tenant models P0 se architecture mein hon; P4 production hardening hai. Pehle global single-company tables bana kar baad mein tenant ID patch karna mana.

**BUILD-02:** Solo pilot P5 ke baad sirf tested scope ke saath ho sakta hai. P6 se pehle manager upsell visible mock ya paid entitlement sale na ho. Full requested product P7 ke baad hi release-candidate kaha jaye.

**BUILD-03:** Owner ko test APK, sample documents, 5-minute walkthrough aur Roman Urdu test checklist har phase mein mile. Source code hi handover na ho.

**BUILD-04:** Expected performance targets: reference low/mid-range Android device par 10-worker local batch save p95 under 1 second; common screen load under 2 seconds; 1,000-row timesheet PDF under 10 seconds. Dataset/device specs pehle fix hon. Yeh targets hain; test ke baghair claims nahin.

**BUILD-05:** Launch capacity fixture 300 active workers, 24 months history, multiple clients/sites aur 2 devices. Badi capacity marketing mein add karne se pehle new benchmark ho.

**BUILD-06:** Phase approval non-developer owner ki visual demo + automated test evidence + specialist security/legal checks ka combination ho. AI ka self-score release approval nahin.

## 22 | Claude aur GitHub: kuch miss na hone ka nizam

**AI-01 — Repo source of truth:** PRD_Roman_Urdu.md, CLAUDE.md, TASKS.md, PROGRESS.md, DECISIONS.md, REQUIREMENTS_TRACEABILITY.md, TEST_CASES.md aur CHANGELOG.md repository mein hon. Har session ka pehla kaam relevant files aur git status read karna ho.

**AI-02 — Work discipline:** Aik waqt mein aik small task. Stable requirement ID > GitHub issue > branch > implementation > test > evidence > PR. Task states: NOT_STARTED, IN_PROGRESS, BLOCKED, IMPLEMENTED_UNVERIFIED, VERIFIED, OWNER_ACCEPTED.

**AI-03 — Done ka matlab:** Feature code + actual wiring + persistence + permissions + error/offline states + tests pass + doc update + runnable build/demo + owner acceptance jahan required. Test run na hua ho to VERIFIED mana. Mock dashboard ko real numbers na kaha jaye.

**AI-04 — Session handover:** Current branch/commit, completed items, pending bugs, exact next task, commands/results aur known risks PROGRESS mein. Context limit se pehle checkpoint commit. Agli session purani chat ki yaad par nahin, repo status par chale.

**AI-05 — GitHub:** Private repository under Asad-owned account/org; small commits; branch protection/CI checks; secrets scanning; dependency lockfiles; releases/tags; issue/PR templates. No credentials, real customer records, keystore/private signing keys ya production backup committed.

**AI-06 — CI gates:** Static analysis, domain arithmetic tests, migrations, auth/tenant-access tests, document smoke tests, web build aur Android build. Failed CI ke bawajood task ko green na karein. Integration tests ke missing credentials ko BLOCKED label karein, skip ko pass nahin.

**AI-07 — No silent changes:** Scope, prices, deductions, payroll formula, tenant permission, data retention aur store billing change ke liye decision log. Deferred requirement ko explicitly owner-approved defer status mile; unimplemented button hide ho ya clear unavailable ho, pretend na kare.

**AI-08 — Full ownership:** Source, store account, domain, cloud project, email provider, signing assets aur backups user-owned credentials/control mein. Independent reviewer aur future buyer ke liye runbook, dependency licenses, environment sample aur reproducible build instructions hon.

Is pack mein code/GitHub repository create nahin ki gayi. Yeh coding ke liye handover hai; development status sab tasks par sach-sach NOT_STARTED se shuru hoga.

## 23 | Acceptance tests aur final owner checklist

**QA-01:** Aik complete end-to-end test: signup > apni company > 2 clients/sites > mixed-pay workers > bulk attendance > payroll/partial payment > timesheet > VAT invoice > partial receipt > PDF share > backup > restore. Har module ka alag demo kaafi nahin.

| Test group | Lazmi nateeja |
| --- | --- |
| Salary carry-forward | 1,000 earned, 500 paid; next 1,000 = 1,500 due; no duplicate expense |
| Advance recovery | 300 issued, 100 recovered = 200 loan balance; salary balance correct |
| Break and rates | Client/payroll breaks independent; 10-worker examples exact |
| Billing | Repeated invoice action same work ko dobara charge na kare |
| VAT | 1,100 + 55 = 1,155; 500 receipt ke baad 655 due |
| Isolation | A ka login/API/storage/restore B ka data access na kar sake |
| Manager | Attendance-only manager payroll payload fetch na kar sake |
| Offline/retry | App restart/retry se entry na gum ho, na duplicate ho |
| Documents | Har exported paper ke har page par correct tenant letterhead |
| Backup | New device par authorized restore totals aur invoice history match kare |
| Metrics | 1 tenant, 2 users, 2 devices = 1 customer; not 2 customers |
| Expiry | Paid/trial expiry par data aur basic export delete/block na hon |

**Owner ki final tasdeeq:** Kya main 10 workers ki hazri khud daal sakta hoon? Kya monthly/hourly/shift worker ka hisaab clear hai? Kya purana salary balance bach raha hai? Kya har document meri company ka lagta hai? Kya manager sirf allowed data dekh raha hai? Kya mujhe app customers, paid receipts aur issues apne dashboard mein samajh aa rahe hain?

**Production se pehle independent gate:** Accountant/payroll expert calculation aur legal treatment review; security reviewer tenant isolation/keys/backup review; actual low-end Android tests; Play policy/privacy/data-deletion forms; production SMTP; restore drill; subscription/payment audit; staged pilot sign-off.

**Jo abhi baqi hai:** App naam/branding final, business/pricing validation, implementation, actual testing, legal/store review, deployment aur customer pilot. Yeh PRD in cheezon ka plan hai, unke ho chukne ka dawa nahin.

## 24 | Official sources aur verification notes

Neechay sources 30-10-2026 ko check kiye gaye. Yeh selected technical/regulatory points ko support karte hain; baqi UX, plans, architecture boundaries aur test targets is project ki design proposals hain. Policies/prices launch se pehle dobara check karein.

**[S01] Flutter — Offline-first support.** Local repository/sync pattern ki bunyaad. https://docs.flutter.dev/app-architecture/design-patterns/offline-first

**[S02] Supabase — Auth; Row Level Security.** Auth ke saath server-side tenant policies. https://supabase.com/docs/guides/auth ; https://supabase.com/docs/guides/database/postgres/row-level-security

**[S03] Supabase — Billing; Free project pausing.** Free-tier limits aur inactivity pause; zero-cost production ka guarantee nahin. https://supabase.com/docs/guides/platform/billing-on-supabase ; https://supabase.com/docs/guides/platform/free-project-pausing

**[S04] Supabase — Custom SMTP.** Default mail service ki restrictions; production login/reset emails ke liye configured provider. https://supabase.com/docs/guides/auth/auth-smtp

**[S05] UAE Federal Tax Authority — Tax Invoices.** Invoice-field reference aur tax-invoice guidance. https://tax.gov.ae/en/taxes/Vat/vat.topics/tax.invoices.aspx ; https://tax.gov.ae/Datafolder/Files/Pdf/2023/Knowledge%20Center%20Page/VAT11%20-%20Tax%20invoices%20En.pdf

**[S06] UAE Ministry of Finance — eInvoicing.** Structured eInvoice PDF/Word/image se alag; current scope/documents aur accredited-provider references. https://mof.gov.ae/en/about-us/initiatives/einvoicing/

**[S07] UAE FTA — e-Invoicing deadlines, 25-10-2026 notice.** Latest surfaced notice ko older deadline announcement par tarjeeh di gayi. In-scope AED 50m+ implementation 01-01-2027; smaller businesses 01-07-2027. https://tax.gov.ae/en/media.centre/News/federal.tax.authority.calls.on.persons.subject.to.einvoicing.to.comply.wit.the.prescribed.legal.deadlines.and.avoid.administrative.penalties.aspx

**[S08] Google Play — Payments policy; Understanding Payments policy.** Paid digital features aur consumption-only distinction. Final approved user journey launch gate hai. https://support.google.com/googleplay/android-developer/answer/9858738 ; https://support.google.com/googleplay/android-developer/answer/10281818

**[S09] Google Play — App account deletion requirements.** App/web deletion path aur disclosed legitimate retention. https://support.google.com/googleplay/android-developer/answer/13327111

**[S10] UAE official government — Payment of salaries/wages.** Wages due-date/WPS obligations; app carry-forward compliance ka substitute nahin. https://u.ae/en/information-and-services/jobs/employment-in-the-private-sector/payment-of-wages

**[S11] Google Play — Download and export monthly reports.** Install/statistics source aur reporting delay. https://support.google.com/googleplay/android-developer/answer/6135870

**Source use note:** Sources ka limited paraphrase hua hai; rates/prices ki proposed table vendor quotation nahin. Regulatory review koi automated legal guarantee nahin. Har source ki current official version launch review mein dobara kholi jaye.


Github
https://github.com/Asadgill-1/labour-managmet.git
