# deb_report.sh — разбирает deb-пакет и генерирует markdown-отчёт
# Использование:  ./deb_report.sh имя_пакета      (например: ./deb_report.sh git)

#1. Проверяем, что передали название пакета
if [ -z "$1" ]; then
    echo "Использование: $0 имя_пакета"
    exit 1
fi

PACKAGE=$1                              # имя пакета из первого аргумента
WORKDIR=$(pwd)/deb_reports/$PACKAGE     # папка, где будем всё разбирать
REPORT=$WORKDIR/$PACKAGE.md             # итоговый markdown-файл

#2. Создаём рабочую папку и переходим в неё
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

#3. Скачиваем deb-пакет (без установки)
echo "Скачиваю пакет $PACKAGE"
apt download "$PACKAGE"
if [ $? -ne 0 ]; then
    echo "Не удалось скачать пакет. Попробуйте: sudo apt update"
    exit 1
fi

#Имя файла заранее не знаем (там версия и %3a), поэтому ищем по шаблону
DEB_FILE=$(ls ${PACKAGE}_*.deb | head -n 1)
echo "Скачан файл: $DEB_FILE"

#4. Распаковываем пакет
rm -rf data meta                        # чистим старые результаты, если были
dpkg -x "$DEB_FILE" data                # -x : сами файлы программы
dpkg -e "$DEB_FILE" meta                # -e : служебные файлы (control, скрипты)

#5.Генерируем отчёт
#5.1.Заголовок — ASCII-баннер через figlet (в блоке кода, чтобы не поехал)
echo '```' > "$REPORT"
figlet -f banner "$PACKAGE" >> "$REPORT"
echo '```' >> "$REPORT"
echo "" >> "$REPORT"

# 5.2.Информация о пакете из apt show
#   2>/dev/null       — прячем предупреждение apt
#   sed 's/$/  /'     — два пробела в конце строки = перенос строки в markdown
#   второй sed        — делает ключи вида "Package:" жирными
apt show "$PACKAGE" 2>/dev/null | sed 's/$/  /' | sed -E 's/^([A-Za-z0-9-]+:) /**\1** /' >> "$REPORT"
echo "" >> "$REPORT"

# 5.3.Структура пакета — дерево папок (3 уровня вглубь)
echo "## Структура пакета" >> "$REPORT"
echo "" >> "$REPORT"
echo '```' >> "$REPORT"
(cd data && tree -L 3) >> "$REPORT"     # cd внутри скобок, чтобы корень был "."
echo '```' >> "$REPORT"
echo "" >> "$REPORT"

# 5.4.Скрипты установки/удаления (если они есть в пакете)
for SCRIPT in preinst postinst prerm postrm; do
    if [ -f "meta/$SCRIPT" ]; then
        echo "## Файл $SCRIPT" >> "$REPORT"
        echo "" >> "$REPORT"
        echo '```bash' >> "$REPORT"
        cat "meta/$SCRIPT" >> "$REPORT"
        echo '```' >> "$REPORT"
        echo "" >> "$REPORT"
    fi
done

echo "Готово! Отчёт: $REPORT"
