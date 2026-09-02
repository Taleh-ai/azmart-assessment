order API findings (5202 sifaris, 10708 order line)

order_ts - hem GMT hem ISO offset formatinda yazilib, eynilesdirme lazimdir (4164 / 518)

order_ts - DD.MM.YYYY formatinda naive gelen deyerler var, bunlar Baki lokalidir (416)

order_ts millisecond formatinda dusur, hansiki fix edilmelidir (104)

order_ts - 2019-cu ilden gelen 1 sifaris var, qalan hamisi 2026-05...08 araligindadir. O0004242

epoch deyerlerde order_ts updated_at-dan millisaniye ile boyuk gorunur, bu xeta deyil, DQ qaydasi yazanda nezere almaq lazimdir (5 setir)

updated_at temizdir, 5202 setrin hamisi ISO Z. incremental watermark-i bunun uzerine qururam

currency kohne deprecated currency qalib, meselen AZM. O0003666 (1)

currency columnlarinda bosluqlar var, ' USD '. O0002505 (1)

currency kicik herfle de gelir, azn ve eur. O0000913, O0001444 (2)

dublikat order idler var idi. O0001017 tam eyni iki setir, O0002222 ise iki ferqli versiya (2)

bir sifarisin icinde eyni product_id iki defe gelir. O0002929, P0010. buna gore grain (order_id, product_id) ola bilmez, line index lazimdir (1)

unit pricelarda menfi deyerler var. O0002401 (1)

unit pricelarda null deyer var. O0004100 (1)

unit priceda formatda problem var, string ile vergul kimi dusur. "2,238.04" (5)

quantity 0 olan deyer var. O0003003 (1)

quantity menfi olan deyer var. O0003113 (1)

customer_id bos string kimi gelir, null deyil. O0000777. not_null testi bunu buraxir (1)

customer_id snapshotlarda olmayan deyer var, C9999. O0001500 (1)

product_id products.csv-de olmayan deyer var, P9999. O0002718 (1)

apidan gelen melumatlar bir nece status ehtiva edir ozunde. dusunurem ki silvere temizlenmis dq edilmis hali dussun. gold layerde ise butun sifarisler qalir, CANCELLED ve REFUNDED silinmir, is_recognized flag ile ayrilir - cancel/refund rate sorgusu ucun onsuz da lazimdir. 384 CANCELLED + 165 REFUNDEDwa