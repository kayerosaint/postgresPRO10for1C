(ENG)
Greetings. This script is designed to install postgresqlpro (a special version for the 1C program) and configure it automatically exclusively on Centos 7.
The memory and processor data for configuring the postgres configuration are taken from the htop utility. Root privileges are required for application.
Attention! Do not try to use this script if you already have classic postgresql installed, this action has not been tested and will probably lead to a breakdown.
When first applied, the program creates a backup copy of the default postgres settings to the current directory, and if the configuration file breaks, it can be restored from the backup with the "make restore" command (the script also uses this command if self-check fails)
The script is primarily intended for use during the initial installation of the system and is written for the following versions: postgrespro-1c-10-server-10.6-1.el7.x86_64 postgrespro-1c-10-contrib-10.6-1.el7.x86_64
Probably, this script will be further optimized
(RU)
Приветствую. Данный скрипт предназначен для установки postgresqlpro (специальной версии для программы 1С) и его автоматической настройки исключительно на Centos 7.
Данные памяти и процессора для настройки конфигурации postgres берутся из утилиты htop. Обязательно нужны привелегии root для применения.
Внимание! Не пытайтесь применить данный скрипт, если у вас уже установлена классическая postgresql, данное действие не было протестировано и вероятно приведет к поломке.
При первом применении программа создает резервную копию настроек postgres по-умолчанию в текущую дирректорию, и если сломается конфигурационный файл, то его можно восстановить из резервной копии командой "make restore" (данную команду также применяет скрипт, если не пройдет self-check)
Скрипт в первую очередь предназначен для применения при первичной установке системы и написан под следующие версии: postgrespro-1c-10-server-10.6-1.el7.x86_64 postgrespro-1c-10-contrib-10.6-1.el7.x86_64
Вероятно, данный скрипт будет в дальнешем оптимизирован
