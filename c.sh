#!/bin/bash
LANG1="eng-kjv"
LANG2="latVUC"
LANG3="grcbrent"
BOOK="GEN"
KEEP=1

# No need to change these
F1="$LANG1.txt"
F2="$LANG2.txt"
F3="$LANG3.txt"

usage() {
	echo "Usage: $0 [3 Letter Book name]"
	echo ""
	echo "Options:"
	echo "  h    Show this message and exit"
	echo "  l    Display available languages and exit"
	echo "To change the languages, modify 'LANG1', 'LANG2', and 'LANG3' in this script"
	echo "By default, they are $LANG1, $LANG2, and $LANG3."
	echo "If you want to keep the intermediate .txt files, change KEEP to anything but 1"
	exit 1
}

available() {
	echo "Available languages: "
	sqlite3 giant_bible.sqlite "SELECT GROUP_CONCAT(DISTINCT version_id) from verse"
	exit 1
}

joiner() {
	join --nocheck-order -v 1 -t $'\t' <(sort -V -k1,1 "$1") <(sort -V -k1,1 "$2") | awk $'{print $1 "\t" $2 "\t" $3 "\t[Missing from text]"}' >> "$2"
	join --nocheck-order -v 2 -t $'\t' <(sort -V -k1,1 "$1") <(sort -V -k1,1 "$2") | awk $'{print $1 "\t" $2 "\t" $3 "\t[Missing from text]"}' >> "$1"
}

query() {
	# We need 'canon_order' for later on, 'chapter' for compiling using xelatex
	sqlite3 giant_bible.sqlite ".mode tabs" "SELECT canon_order, chapter, start_verse, text
	FROM verse
	WHERE
		(version_id = '$1') AND
		(book = '$BOOK');" > "$2"
}

generate() {
	# We start by getting the 3 languages we want.
	query "$LANG1" "$F1"
	printf "." # just progress display stuff.
	query "$LANG2" "$F2"
	printf "."
	query "$LANG3" "$F3"
	printf "."
}

cleanup() {
	rm output.txt && rm "$F1" && rm "$F2" && rm "$F3"
}

doit() {
	generate

	# Some versions/translations either combine verses, or number them slightly
	# differently, or whatever. This makes it a problem to line up the different
	# verses together. These 'join's find the missing lines in each version and
	# insert them into the appropriate file.
	# Since we have 3 languages, we have to do this for each combination of files.
	joiner "$F1" "$F2"
	printf "."
	joiner "$F2" "$F3"
	printf "."
	joiner "$F1" "$F3"
	printf "."

	# Now that the files are all the same size with the same values, we join them together.
	join --nocheck-order -o 1.1,1.2,1.3,1.4,2.4 -t $'\t' <(sort -V -k1,1 "$F1") <(sort -V -k1,1 "$F2") > output.txt
	printf "."
	join --nocheck-order -o 1.1,1.2,1.3,1.4,1.5,2.4 -t $'\t' <(sort -V -k1,1 "output.txt") <(sort -V -k1,1 "$F3") > outputfinal.txt
	printf ".\n"

	if [ $KEEP = 1 ]; then
		cleanup
	fi
	xelatex create.tex -jobname="$BOOK"
	mv create.pdf "$BOOK.pdf"
	echo ""
	echo "File created at $BOOK.pdf"
}

# Didn't pass in a book.
[ -z $1 ] && usage && exit 1

case "$1" in
	h*) usage && exit 1 ;;
	l*) available ;;
	*) l=`echo $1 | wc -c` && [ $l != "4" ] && usage && exit 1
		# book length is not 3 (4 includes ending char), that's the
		# only testing i'll do for now
		BOOK="$1" && doit ;;
esac
