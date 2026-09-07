# AI istifadəsi

Alətlər: Claude (Anthropic, Claude Code) və JetBrains AI.

**JetBrains AI** — yalnız səliqəli commit mesajlarının yazılmasında istifadə etmişəm.

**Claude** — aşağıdakılarda köməkçi kimi istifadə etmişəm:

- Ümumi kodların yazılmasında dəstək və optimizasiya (o cümlədən dbt modelləri və Airflow DAG-ın icrası zamanı)
- Docker compose və docker fayllarının hazırlanması
- Server üzərində test etmək üçün query-lərin hazırlanması (debug məqsədilə)
- md fayllarının səliqəyə salınması

Qərarları (dedup qaydası, tombstone handling, status source-of-truth, SCD2 strategiyası) özüm vermişəm; 
Claude-un yazdığı kodu real datada (dbt build, Airflow dags test) test edib təsdiqləmişəm.