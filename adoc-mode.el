;;; adoc-mode.el --- a major-mode for editing AsciiDoc files in Emacs
;;
;; Copyright 2010 Florian Kaufmann <sensorflo@gmail.com>
;;
;; Author: Florian Kaufmann <sensorflo@gmail.com>
;; URL: http://code.google.com/p/adoc-mode/
;; Created: 2009
;; Version: 0.4.0
;; Keywords: wp AsciiDoc
;; 
;; This file is not part of GNU Emacs.
;; 
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;
;;; Commentary:
;; 
;; AsciiDoc (http://www.methods.co.nz/asciidoc/) is a text document format for
;; writing short documents, articles, books and UNIX man pages. AsciiDoc files
;; can be translated to HTML and DocBook markups.
;;
;; This is just a first version which works not too bad for my small uses of
;; AsciiDoc. It's mostly about syntax highlighting. I still like to play a lot
;; and thus it's not stable at all.
;;
;; I actually would like to improve it, but realistically will invest
;; my time in other activities.
;;
;; Installation:
;;
;; Installation is as usual, so if you are proficient with Emacs you don't need
;; to read this.
;;
;; 1. Copy this file to a directory in `load-path'. To add a specific directory
;;    to the load path, add this to your initialization file (~/.emacs or ~/_emacs):
;;    (add-to-list 'load-path "mypath")
;;
;; 2. Add either of the two following lines to your initialization file:
;;    a)  (autoload 'adoc-mode "adoc-mode")
;;    b)  (require 'adoc-mode)
;;    The first only loads adoc mode when necessary, the 2nd always during
;;    startup of Emacs.
;;
;; 3. To use adoc mode, call adoc-mode after you opened an AsciiDoc file
;;    M-x adoc-mode
;;
;; Each of the following is optional
;;
;; * Byte compile this file (adoc-mode.el) for faster startup: 
;;   M-x byte-compile
;;
;; * According to AsciiDoc manual, '.txt' is the standard file extension for
;;   AsciiDoc files. Add the following to your initialization file to open all
;;   '.txt' files with adoc-mode as major mode automatically:
;;   (add-to-list 'auto-mode-alist (cons "\\.txt\\'" 'adoc-mode))
;;
;; * If your default face is a fixed pitch (monospace) face, but in AsciiDoc
;;   files you liked to have normal text with a variable pitch face,
;;   `buffer-face-mode' is for you: 
;;   (add-hook 'adoc-mode-hook (lambda() (buffer-face-mode t)))
;;
;;
;; Todo:
;; - Fontlock
;;   - make font-lock regexps based upon AsciiDoc configuration file, or
;;     make them configurable in a way similar to that configuration file
;;   - respect font-lock-maximum-decoration
;; - Other common emacs functionality/features
;;   - indent functions
;;   - imenu / outline / hideshow
;;   - tags
;;   - Make 'compilation', i.e. translating into the desired output format more
;;     conventient
;;   - tempo-templates
;;   - spell check shall ignore text that is not part of the output
;;   - supply a regexp for magic-mode-alist
;;   - Is there something that would remove hard newlines within a paragraph,
;;     but just for display, so the paragraph uses the whole buffer length.
;;   - are there generic base packages to handle lists / tables?
;; - AsciiDoc related features
;;   - Two (or gruadualy fading) display modes: one emphasises to see the
;;     AsciiDoc source text, the other emphasises to see how the output will
;;     look like.
;;   - invisible text property could be used to hide meta characters
;;   - tags tables for anchors, indixes, bibliography items, titles, ...
;;
;; Bugs:
;; - delimited blocks are supported, but not well at all
;; - Most regexps for highlighting can spawn at most over two lines.
;; - font-lock's multi line capabilities are not used well enough
;; - AsciiDoc's escape rules don't seem to be what one expects. E.g. \\__bla__
;;   is *not* a literal backslashed followed by an emphasised bla, but an
;;   emphasised _bla_. Try to find out what AsciiDoc's rules are. adoc-mode
;;   currently uses 'common' escaping rule: backslash always makes the following
;;   char literal.
;;
;;; Variables:

(require 'markup-faces)
(require 'cl)

(defconst adoc-mode-version "0.4.0"
  "Based upon AsciiDoc version 8.5.2. I.e. regexeps and rules are taken from
that version's asciidoc.conf/manual.")

(defgroup adoc nil
  "Support for AsciiDoc documents."
  :group 'wp)

(defcustom adoc-script-raise '(-0.3 0.3)
  "How much to lower and raise subscript and superscript content.

This is a list of two floats. The first is negative and specifies
how much subscript is lowered, the second is positive and
specifies how much superscript is raised. Heights are measured
relative to that of the normal text. The faces used are
markup-superscript-face and markup-subscript-face respectively.

You need to call `adoc-calc' after a change."
  :type '(list (float :tag "Subscript")
               (float :tag "Superscript"))
  :group 'adoc)

(defcustom adoc-insert-replacement t
  "When true the character/string a replacment/entity stands for is displayed.

E.g. after '&amp;' an '&' is displayed, after '(C)' the copy right
sign is displayed. It's only about display, neither the file nor
the buffer content is affected.

You need to call `adoc-calc' after you change
`adoc-insert-replacement'. For named character entities (e.g.
'&amp;', in contrast to '&#20;' or '(C)' ) to be displayed you need to
set `adoc-unichar-name-resolver'."
  :type 'boolean
  :group 'adoc)

(defcustom adoc-unichar-name-resolver nil
  "Function taking a unicode char name and returing it's codepoint.

E.g. when given \"amp\" (as in the character entity reference
\"&amp;\"), it shall return 38 (#x26). Is used to insert the
character a character entity reference is refering to after the
entity. When adoc-unichar-name-resolver is nil, or when its
function returns nil, nothing is done with named character
entities. Note that if `adoc-insert-replacement' is nil,
adoc-unichar-name-resolver is not used.

You can set it to `adoc-unichar-by-name'; however it requires
unichars.el (http://nwalsh.com/emacs/xmlchars/unichars.el). When
you set adoc-unichar-name-resolver to adoc-unichar-by-name, you
need to call `adoc-calc' for the change to take effect."
  :type '(choice (const nil)
                 (const adoc-unichar-by-name)
                 function)
  :group 'adoc)

(defcustom adoc-two-line-title-del '("==" "--" "~~" "^^" "++")
  "Delimiter used for the underline of two line titles.
Each string must be exactly 2 characters long. Corresponds to the
underlines element in the titles section of the asciidoc
configuration file."
  :type '(list
          (string :tag "level 0") 
          (string :tag "level 1") 
          (string :tag "level 2") 
          (string :tag "level 3") 
          (string :tag "level 4") )
  :group 'adoc)

(defcustom adoc-delimited-block-del
  '("^/\\{4,\\}"	 ; 0 comment
    "^\\+\\{4,\\}"	 ; 1 pass
    "^-\\{4,\\}"	 ; 2 listing
    "^\\.\\{4,\\}"	 ; 3 literal
    "^_\\{4,\\}"	 ; 4 quote
    "^=\\{4,\\}"	 ; 5 example
    "^\\*\\{4,\\}"	 ; 6 sidebar
    "^--")        	 ; 7 open block
  "Regexp used for delimited blocks.

WARNING: They should not contain a $. It is implied that they
match up to end of the line;

They correspond to delimiter variable blockdef-xxx sections in
the AsciiDoc configuration file.

However contrary to the AsciiDoc configuration file a separate
regexp can be given for the start line and for the end line. You
may want to do that because adoc-mode often can't properly
distinguish between a) a two line tile b) start of a delimited
block and c) end of a delimited block. If you start a listing
delimited block with '>----' and end it with '<----', then all
three cases can easily be distinguished. The regexp in your
AsciiDoc config file would the probably be '^[<>]-{4,}$'"
  :type '(list
	  (choice :tag "comment"
		  (regexp :tag "start/end regexp")
		  (list :tag "separate regexp"
			(regexp :tag "start regexp")
			(regexp :tag "end regexp")))
	  (choice :tag "pass"
		  (regexp :tag "start/end regexp")
		  (list :tag "separate regexp"
			(regexp :tag "start regexp")
			(regexp :tag "end regexp")))
	  (choice :tag "listing"
		  (regexp :tag "start/end regexp")
		  (list :tag "separate regexp"
			(regexp :tag "start regexp")
			(regexp :tag "end regexp")))
	  (choice :tag "literal"
		  (regexp :tag "start/end regexp")
		  (list :tag "separate regexp"
			(regexp :tag "start regexp")
			(regexp :tag "end regexp")))
	  (choice :tag "quote"
		  (regexp :tag "start/end regexp")
		  (list :tag "separate regexp"
			(regexp :tag "start regexp")
			(regexp :tag "end regexp")))
	  (choice :tag "example"
		  (regexp :tag "start/end regexp")
		  (list :tag "separate regexp"
			(regexp :tag "start regexp")
			(regexp :tag "end regexp")))
	  (choice :tag "sidebar"
		  (regexp :tag "start/end regexp")
		  (list :tag "separate regexp"
			(regexp :tag "start regexp")
			(regexp :tag "end regexp")))
	   (choice :tag "open"
		  (regexp :tag "start/end regexp")
		  (list :tag "separate regexp"
			(regexp :tag "start regexp")
			(regexp :tag "end regexp")))))

;; todo: limit value range to 1 or 2
(defcustom adoc-default-title-type 1
  "Default title type, see `adoc-title-descriptor'."
  :group 'adoc)

;; todo: limit value range to 1 or 2
(defcustom adoc-default-title-sub-type 1
  "Default title sub type, see `adoc-title-descriptor'."
  :group 'adoc  )

(defcustom adoc-enable-two-line-title t
  "Wether or not two line titles shall be fontified.

nil means never fontify. t means always fontify. A number means
only fontify if the line below has NOT the lenght of the given
number. You could use a number for example when all your
delimited block lines have a certain length.

This is usefull because adoc-mode has troubles to properly
distinguish between two line titles and a line of text before a
delimited block. Note however that adoc-mode knows the AsciiDoc
rule that the length of a two line title underline can differ at
most 3 chars from the length of the title text."
  :type '(choice (const nil)
		 (const t)
		 number)
  :group 'adoc)

(define-obsolete-face-alias 'adoc-orig-default 'adoc-align "23.3")
(defface adoc-align
  '((t (:inherit (markup-meta-face))))
  "Face used so the text looks left aligned.

Is applied to whitespaces at the beginning of a line. You want to
set it to a fixed width face. This is useful if your default face
is a variable with face. Because for e.g. in a variable with
face, '- ' and ' ' (two spaces) don't have equal with, with
`adoc-align' in the following example the item's text looks
aligned.

- lorem ipsum
  dolor ..."
  :group 'adoc)

(define-obsolete-face-alias 'adoc-generic 'markup-gen-face "23.3")
(define-obsolete-face-alias 'adoc-monospace 'markup-typewriter-face "23.3")
(define-obsolete-face-alias 'adoc-strong 'markup-strong-face "23.3")
(define-obsolete-face-alias 'adoc-emphasis 'markup-emphasis-face "23.3")
(define-obsolete-face-alias 'adoc-superscript 'markup-superscript-face "23.3")
(define-obsolete-face-alias 'adoc-subscript 'markup-subscript-face "23.3")
(define-obsolete-face-alias 'adoc-secondary-text 'markup-secondary-text-face "23.3")
(define-obsolete-face-alias 'adoc-replacement 'markup-replacement-face "23.3")
(define-obsolete-face-alias 'adoc-complex-replacement 'markup-complex-replacement-face "23.3")
(define-obsolete-face-alias 'adoc-list-item 'markup-list-face "23.3")
(define-obsolete-face-alias 'adoc-table-del 'markup-table-face "23.3")
(define-obsolete-face-alias 'adoc-reference 'markup-reference-face "23.3")
(define-obsolete-face-alias 'adoc-delimiter 'markup-meta-face "23.3")
(define-obsolete-face-alias 'adoc-hide-delimiter 'markup-hide-delimiter-face "23.3")
(define-obsolete-face-alias 'adoc-anchor 'markup-anchor-face "23.3")
(define-obsolete-face-alias 'adoc-comment 'markup-comment-face "23.3")
(define-obsolete-face-alias 'adoc-warning 'markup-error-face "23.3")
(define-obsolete-face-alias 'adoc-preprocessor 'markup-preprocessor-face "23.3")

;; Despite the comment in font-lock.el near 'defvar font-lock-comment-face', it
;; seems I still need variables to refer to faces in adoc-font-lock-keywords.
;; Not having variables and only referring to face names in
;; adoc-font-lock-keywords does not work.
(defvar adoc-align 'adoc-align)
(defvar adoc-generic 'markup-gen-face)
(defvar adoc-monospace 'markup-typewriter-face)
(defvar adoc-replacement 'markup-replacement-face)
(defvar adoc-complex-replacement 'markup-complex-replacement-face)
(defvar adoc-table-del 'markup-table-face)
(defvar adoc-reference 'markup-reference-face)
(defvar adoc-secondary-text 'markup-secondary-text-face)
(defvar adoc-delimiter 'markup-meta-face)
(defvar adoc-hide-delimiter 'markup-meta-hide-face)
(defvar adoc-anchor 'markup-anchor-face)
(defvar adoc-comment 'markup-comment-face)
(defvar adoc-warning 'markup-error-face)
(defvar adoc-preprocessor 'markup-preprocessor-face)

(defconst adoc-title-max-level 4
  "Max title level, counting starts at 0.")

(defconst adoc-uolist-max-level 5
  "Max unordered (bulleted) list item nesting level, counting starts at 0.")

;; I think it's actually not worth the fuzz to try to sumarize regexps until
;; profiling profes otherwise. Nevertheless I can't stop doing it.
(defconst adoc-summarize-re-uolisti t
  "When non-nil, sumarize regexps for unordered list items into one regexp.
To become a customizable variable when regexps for list items become customizable.")

(defconst adoc-summarize-re-olisti t
  "As `adoc-summarize-re-uolisti', but for ordered list items.")

(defconst adoc-summarize-re-llisti t
  "As `adoc-summarize-re-uolisti', but for labeled list items.")

(defvar adoc-unichar-alist nil
  "An alist, key=unicode character name as string, value=codepoint.")

(defvar adoc-mode-hook nil
  "Normal hook run when entering Adoc Text mode.")

(defvar adoc-mode-abbrev-table nil
  "Abbrev table in use in adoc-mode buffers.")

(defvar adoc-font-lock-keywords nil
  "Font lock keywords in adoc-mode buffers.")

(defvar adoc-replacement-failed nil )

(define-abbrev-table 'adoc-mode-abbrev-table ())

;;; Code:

;; from asciidoc.conf:
;; ^:(?P<attrname>\w[^.]*?)(\.(?P<attrname2>.*?))?:(\s+(?P<attrvalue>.*))?$
(defun adoc-re-attribute-entry ()
  (concat "^\\(:[a-zA-Z0-9_][^.\n]*?\\(?:\\..*?\\)?:[ \t]*\\)\\(.*?\\)$"))

;; from asciidoc.conf:
;; ^= +(?P<title>[\S].*?)( +=)?$
(defun adoc-re-one-line-title (level)
  "Returns a regex matching a one line title of the given LEVEL.
When LEVEL is nil, a one line title of any level is matched.

match-data has this sub groups:
1 leading delimiter inclusive whites between delimiter and title text
2 title's text exclusive leading/trailing whites
3 trailing delimiter with all whites 
4 trailing delimiter only inclusive whites between title text and delimiter
0 only chars that belong to the title block element

== my title ==  n
--12------23----
             4-4"
  (let* ((del (if level
                 (make-string (+ level 1) ?=)
               (concat "=\\{1," (+ adoc-title-max-level 1) "\\}"))))
    (concat
     "^\\("  del "[ \t]+\\)"		      ; 1
     "\\([^ \t\n].*?\\)"		      ; 2
     "\\(\\([ \t]+" del "\\)?[ \t]*\n\\)" ))) ; 3 & 4

(defun adoc-make-one-line-title (sub-type level text)
  "Returns a one line title of LEVEL and SUB-TYPE containing the given text."
  (let ((del (make-string (+ level 1) ?=)))
    (concat del " " text (when (eq sub-type 2) (concat " " del)))))   

;; for first line, 2nd line is not a regex but python code
;; ^(?P<title>.*?)$   
(defun adoc-re-two-line-title (del)
  "Note that even if this regexp matches it still doesn't mean it is a two line title.
You additionaly have to test if the underline has the correct length.

match-data has his this sub groups:
1 title's text
2 delimiter
0 only chars that belong to the title block element"
  (when (not (eq (length del) 2))
    (error "two line title delimiters must be 2 chars long"))
  (concat
   ;; title text (the first line) must contain at least one \w character. You
   ;; don't see that in asciidoc.conf, only in asciidoc source code.
   "\\(^.*?[a-zA-Z0-9_].*?\\)[ \t]*\n" 
   "\\("
     "\\(?:" (regexp-quote del) "\\)+"
     (regexp-quote (substring del 0 1)) "?"   
   "\\)[ \t]*$" ))

(defun adoc-make-two-line-title (del text)
  "Returns a two line title using given DEL containing given TEXT."
  (when (not (eq (length del) 2))
    (error "two line title delimiters must be 2 chars long"))
  (let ((repetition-cnt (if (>= (length text) 2) (/ (length text) 2) 1))
        (result (concat text "\n")))
    (while (> repetition-cnt 0)
      (setq result (concat result del))
      (setq repetition-cnt (- repetition-cnt 1)))
    (when (eq (% (length text) 2) 1)
      (setq result (concat result (substring del 0 1))))
    result))
  
(defun adoc-re-oulisti (type &optional level sub-type)
  "Returns a regexp matching an (un)ordered list item.

match-data his this sub groups:
1 leading whites
2 delimiter
3 trailing whites between delimiter and item's text
0 only chars belonging to delimiter/whites. I.e. none of text.

WARNING: See warning about list item nesting level in `adoc-list-descriptor'."
  (cond

   ;;   ^\s*- +(?P<text>.+)$                     normal 0           
   ;;   ^\s*\* +(?P<text>.+)$                    normal 1
   ;;   ...                                      ...
   ;;   ^\s*\*{5} +(?P<text>.+)$                 normal 5
   ;;   ^\+ +(?P<text>.+)$                       bibliograpy(DEPRECATED)     
   ((eq type 'adoc-unordered)
    (cond
     ((or (eq sub-type 'adoc-normal) (null sub-type))
      (let ((r (cond ((numberp level) (if (eq level 0) "-" (make-string level ?\*)))
                     ((or (null level) (eq level 'adoc-all-levels)) "-\\|\\*\\{1,5\\}")
                     (t (error "adoc-unordered/adoc-normal: invalid level")))))
        (concat "^\\([ \t]*\\)\\(" r "\\)\\([ \t]+\\)")))
     ((and (eq sub-type 'adoc-bibliography) (null level))
      "^\\(\\)\\(\\+\\)\\([ \t]+\\)")
     (t (error "adoc-unordered: invalid sub-type/level combination"))))

   ;;   ^\s*(?P<index>\d+\.) +(?P<text>.+)$      decimal = 0
   ;;   ^\s*(?P<index>[a-z]\.) +(?P<text>.+)$    lower alpha = 1
   ;;   ^\s*(?P<index>[A-Z]\.) +(?P<text>.+)$    upper alpha = 2
   ;;   ^\s*(?P<index>[ivx]+\)) +(?P<text>.+)$   lower roman = 3
   ;;   ^\s*(?P<index>[IVX]+\)) +(?P<text>.+)$   upper roman = 4
   ((eq type 'adoc-explicitly-numbered)
    (when level (error "adoc-explicitly-numbered: invalid level"))
    (let* ((l '("[0-9]+\\." "[a-z]\\." "[A-Z]\\." "[ivx]+)" "[IVX]+)"))
           (r (cond ((numberp sub-type) (nth sub-type l))
                    ((or (null sub-type) (eq sub-type 'adoc-all-subtypes)) (mapconcat 'identity l "\\|"))
                    (t (error "adoc-explicitly-numbered: invalid subtype")))))
      (concat "^\\([ \t]*\\)\\(" r "\\)\\([ \t]+\\)")))

   ;;   ^\s*\. +(?P<text>.+)$                    normal 0
   ;;   ^\s*\.{2} +(?P<text>.+)$                 normal 1
   ;;   ... etc until 5                          ...
   ((eq type 'adoc-implicitly-numbered) 
    (let ((r (cond ((numberp level) (number-to-string (+ level 1)))
                   ((or (null level) (eq level 'adoc-all-levels)) "1,5")
                   (t (error "adoc-implicitly-numbered: invalid level")))))
      (concat "^\\([ \t]*\\)\\(\\.\\{" r "\\}\\)\\([ \t]+\\)")))

   ;;   ^<?(?P<index>\d*>) +(?P<text>.+)$        callout
   ((eq type 'adoc-callout)
    (when (or level sub-type) (error "adoc-callout invalid level/sub-type"))
    "^\\(\\)\\(<?[0-9]*>\\)\\([ \t]+\\)")

   ;; invalid
   (t (error "invalid (un)ordered list type"))))
     
(defun adoc-make-uolisti (level is-1st-line)
  "Returns a regexp matching a unordered list item."
  (let* ((del (if (eq level 0) "-" (make-string level ?\*)))
         (white-1st (if indent-tabs-mode
                        (make-string (/ (* level standard-indent) tab-width) ?\t)
                      (make-string (* level standard-indent) ?\ )))
         (white-rest (make-string (+ (length del) 1) ?\ )))
    (if is-1st-line
        (concat white-1st del " ")
      white-rest)))

(defun adoc-re-llisti (type level)
  "Returns a regexp matching a labeled list item.
Subgroups:
1 leading blanks
2 label text, incl whites before delimiter
3 delimiter incl trailing whites
4 delimiter only

  foo :: bar
-12--23-3
      44"
  (cond
   ;; ^\s*(?P<label>.*[^:])::(\s+(?P<text>.+))?$    normal 0
   ;; ^\s*(?P<label>.*[^;]);;(\s+(?P<text>.+))?$    normal 1
   ;; ^\s*(?P<label>.*[^:]):{3}(\s+(?P<text>.+))?$  normal 2
   ;; ^\s*(?P<label>.*[^:]):{4}(\s+(?P<text>.+))?$  normal 3
   ((eq type 'adoc-labeled-normal)
    (let* ((deluq (nth level '("::" ";;" ":::" "::::"))) ; unqutoed
           (del (regexp-quote deluq))
           (del1st (substring deluq 0 1)))
      (concat
       "^\\([ \t]*\\)"			; 1
       "\\(.*[^" del1st "\n]\\)"	; 2
       "\\(\\(" del "\\)\\(?:[ \t]+\\|$\\)\\)"))) ; 3 & 4

   ;; glossary (DEPRECATED)
   ;; ^(?P<label>.*\S):-$                        
   ((eq type 'adoc-labeled-qanda)
    (concat
     "^\\([ \t]*\\)"			; 1
     "\\(.*[^ \t\n]\\)"			; 2
     "\\(\\(\\?\\?\\)\\)$"))		; 3 & 4

   ;; qanda (DEPRECATED)
   ;; ^\s*(?P<label>.*\S)\?\?$                      
   ((eq type 'adoc-labeled-glossary)
    (concat
     "^\\(\\)"				; 1
     "\\(.*[^ \t\n]\\)"			; 2
     "\\(\\(:-\\)\\)$"))		; 3 & 4
   (t (error "Unknown type/level"))))

(defun adoc-re-delimited-block-line ()
  (concat
   "\\(?:"
   (mapconcat
    (lambda (x)
      (concat "\\(?:" x "\\)[ \t]*$"))
    adoc-delimited-block-del "\\|")
   "\\)"))

(defun adoc-re-delimited-block (del)
  (let* ((tmp (nth del adoc-delimited-block-del))
	 (start (if (consp tmp) (car tmp) tmp))
	 (end (if (consp tmp) (cdr tmp) tmp)))
    (concat
     "\\(" start "\\)[ \t]*\n"
     "\\(\\(?:.*\n\\)*?\\)"
     "\\(" end "\\)[ \t]*$")))

;; TODO: since its multiline, it doesn't yet work properly.
(defun adoc-re-verbatim-paragraph-sequence ()
  (concat 
   "\\("
   ;; 1. paragraph in sequence delimited by blank line or list continuation
   "^\\+?[ \t]*\n" 

   ;; sequence of verbatim paragraphs
   "\\(?:"
     ;; 1st line starts with blanks, but has also non blanks, i.e. is not empty
     "[ \t]+[^ \t\n].*" 
     ;; 2nd+ line is neither a blank line nor a list continuation line
     "\\(?:\n\\(?:[^+ \t\n]\\|[ \t]+[^ \t\n]\\|\\+[ \t]*[^ \t\n]\\).*?\\)*?" 
     ;; paragraph delimited by blank line or list continuation
     ;; NOTE: now list continuation belongs the the verbatim paragraph sequence,
     ;; but actually we want to highlight it differently. Thus the font lock
     ;; keywoard handling list continuation must come after verbatim paraphraph
     ;; sequence.
     "\n\\+?[ \t]*\n" 
   "\\)+" 

   "\\)" ))

;; ^\.(?P<title>([^.\s].*)|(\.[^.\s].*))$
;; Isn't that asciidoc.conf regexp the same as: ^\.(?P<title>(.?[^.\s].*))$
;; insertion: so that this whole regex doesn't mistake a line starting with a cell specifier like .2+| as a block title 
(defun adoc-re-block-title ()
  "Returns a regexp matching an block title

Subgroups:
1 delimiter
2 title's text incl trailing whites
3 newline 

.foo n
12--23"
  (concat
   "^\\(\\.\\)"
   "\\(\\.?\\(?:"	
   "[0-9]+[^+*]" ; inserted part, see above
   "\\|[^. \t\n]\\).*\\)"
   "\\(\n\\)"))

(defun adoc-re-precond (&optional unwanted-chars backslash-allowed disallowed-at-bol)
  (concat
          (when disallowed-at-bol ".")
          "\\(?:"
          (unless disallowed-at-bol "^\\|")
          "[^"
          (if unwanted-chars unwanted-chars "")
          (if backslash-allowed "" "\\")
          "\n"
          "]"
          "\\)"))

(defun adoc-re-quote-precondition (not-allowed-chars)
  "Regexp that matches before a (un)constrained quote delimiter.

NOT-ALLOWED-CHARS are chars not allowed before the quote."
  (concat
     "\\(?:"   
       "^"     
     "\\|"
       "\\="
     "\\|"
       ; or *not* after
       ; - an backslash
       ; - user defined chars
       "[^" not-allowed-chars "\\\n]" 
     "\\)"))

;; AsciiDoc src:
;; # Unconstrained quotes can appear anywhere.
;; reo = re.compile(r'(?msu)(^|.)(\[(?P<attrlist>[^[\]]+?)\])?' \
;;         + r'(?:' + re.escape(lq) + r')' \
;;         + r'(?P<content>.+?)(?:'+re.escape(rq)+r')')
;;
;; BUG: Escaping ala \\**...** does not yet work. Probably adoc-mode should do
;; it like this, which is more similar to how asciidoc does it: 'Allow'
;; backslash as the first char. If the first char is ineed a backslash, it is
;; 'removed' (-> adoc-hide-delimiter face), and the rest of the match is left
;; unaffected.
(defun adoc-re-unconstrained-quote (ldel &optional rdel)
  (unless rdel (setq rdel ldel))
  (let* ((qldel (regexp-quote ldel))
         (qrdel (regexp-quote rdel)))
    (concat
     (adoc-re-quote-precondition "")
     "\\(\\[[^][]+?\\]\\)?"
     "\\(" qldel "\\)"
     "\\(.+?\\(?:\n.*?\\)\\{,1\\}?\\)"
     "\\(" qrdel "\\)")))

;; AsciiDoc src for constrained quotes
;; # The text within constrained quotes must be bounded by white space.
;; # Non-word (\W) characters are allowed at boundaries to accommodate
;; # enveloping quotes.
;;
;; reo = re.compile(r'(?msu)(^|[^\w;:}])(\[(?P<attrlist>[^[\]]+?)\])?' \
;;     + r'(?:' + re.escape(lq) + r')' \
;;     + r'(?P<content>\S|\S.*?\S)(?:'+re.escape(rq)+r')(?=\W|$)')
(defun adoc-re-constrained-quote (ldel &optional rdel)
  "
subgroups:
1 attribute list [optional]
2 starting del
3 enclosed text
4 closing del"
  (unless rdel (setq rdel ldel))
  (let ((qldel (regexp-quote ldel))
        (qrdel (regexp-quote rdel)))
    (concat
     ;; added &<> because those are special chars which are substituted by a
     ;; entity, which ends in ;, which is prohibited in the ascidoc.conf regexp
     (adoc-re-quote-precondition "A-Za-z0-9;:}&<>")  
     "\\(\\[[^][]+?\\]\\)?"
     "\\(" qldel "\\)"
     "\\([^ \t\n]\\|[^ \t\n].*?\\(?:\n.*?\\)\\{,1\\}?[^ \t\n]\\)"
     "\\(" qrdel "\\)"
     ;; BUG: now that Emacs doesn't has look-ahead, the match is too long, and
     ;; adjancted quotes of the same type wouldn't be recognized.
     "\\(?:[^A-Za-z0-9\n]\\|[ \t]*$\\)")))

(defun adoc-re-quote (type ldel &optional rdel)
  (cond
   ((eq type 'adoc-constrained)
    (adoc-re-constrained-quote ldel rdel))
   ((eq type 'adoc-unconstrained)
    (adoc-re-unconstrained-quote ldel rdel))
   (t
    (error "Invalid type"))))

;; todo: use same regexps as for font lock
(defun adoc-re-paragraph-separate ()
  (concat

        ;; empty line
        "[ \t]*$"
        
        ;; delimited blocks / two line titles
        "\\|"
        "\\("
          "^+" "\\|"
          "\\++" "\\|"
          "/+" "\\|"
          "-+" "\\|"
          "\\.+" "\\|"
          "\\*+" "\\|"
          "_*+" "\\|"
          "=*+" "\\|"
          "~*+" "\\|"
          "^*+" "\\|"
          "--"
        "\\)"
        "[ \t]*$"
        ))

;; todo: use same regexps as for font lock
(defun adoc-re-paragraph-start ()
  (concat
        paragraph-separate
        
        ;; list items
        "\\|"
        "[ \t]*"
        "\\("
            "-"                  "\\|"
            "\\*\\{1,5\\}"       "\\|"
            "\\.\\{1,5\\}"       "\\|"
            "[0-9]\\{,3\\}\\."   "\\|"
            "[a-z]\\{,3\\}\\."   "\\|"
            "[A-Z]\\{,3\\}\\."   "\\|"
            "[ivxmcIVXMC]+)"     "\\|"
            ".*?:\\{2,4\\}"
        "\\)"
        "\\( \\|$\\)"
        
        ;; table rows
        "\\|"
        "|"

        ;; one line titles
        "\\|"
        "[=.].*$"
        
        ))

(defun adoc-re-aor(e1 e2)
  "all or: Returns a regex matching \(e1\|e2\|e1e2\)? "
  (concat "\\(?:" e1 "\\)?\\(?:" e2 "\\)?"))

(defun adoc-re-ror(e1 e2)
  "real or: Returns a regex matching \(e1\|e2\|e1e2\)"
  (concat "\\(?:\\(?:" e1 "\\)\\|\\(?:" e2 "\\)\\|\\(?:" e1 "\\)\\(?:" e2 "\\)\\)"))

;; ((?<!\S)((?P<span>[\d.]+)(?P<op>[*+]))?(?P<align>[<\^>.]{,3})?(?P<style>[a-z])?)?\|'
(defun adoc-re-cell-specifier () 
  (let* ((fullspan (concat (adoc-re-ror "[0-9]+" "\\.[0-9]+") "[*+]"))
         (align (adoc-re-ror "[<^>]" "\\.[<^>]"))
         (style "[demshalv]"))
    (concat "\\(?:" fullspan "\\)?\\(?:" align "\\)?\\(?:" style "\\)?")))

(defun adoc-kwf-std (end regexp &optional must-free-groups no-block-del-groups)
  "Standart function for keywords

Intendent to be called from font lock keyword functions. END is
the limit of the search. REXEXP the regexp to be searched.
MUST-FREE-GROUPS a list of regexp group numbers which may not
match text that has an adoc-reserved text-property with a non-nil
value."
  (let ((found t) (prevented t) saved-point)
    (while (and found prevented (<= (point) end) (not (eobp)))
      (setq saved-point (point))
      (setq found (re-search-forward regexp end t))
      (setq prevented 
	    (and found
		 (or
		  (some (lambda(x)
			  (and (match-beginning x)
			       (text-property-not-all (match-beginning x)
						      (match-end x)
						      'adoc-reserved nil)))
			must-free-groups)
		  (some (lambda(x)
			  (and (match-beginning x))
			  (text-property-any (match-beginning x)
					     (match-end x)
					     'adoc-reserved 'block-del))
			no-block-del-groups))))
      (when (and found prevented (<= (point) end))
	(goto-char (1+ saved-point))))
    (and found (not prevented))))

;; (defun adoc-kwf-std (end regexp &rest must-free-groups)
;;   "adoc's standart matcher function for keywords.

;; Intendent to be called from font lock keyword functions. END is
;; the limit of the search. REXEXP the regexp to be searched.
;; MUST-FREE-GROUPS a list of regexp group numbers which may not
;; match text that has an adoc-reserved text-property with a non-nil
;; value."
;;   (let ((found t) (prevented t) ; start value's are semantically not true, but make the loop condition simpler
;; 	saved-point
;; 	(continue t)
;; 	(end2 end))
;;     (while continue
;;       (when (eq (get-text-property (point) 'adoc-reserved) 'block-del)
;; 	(goto-char (next-single-property-change (point) 'adoc-reserved nil end)))
;;       (setq end2 (min (if (eq (get-text-property end 'adoc-reserved) 'block-del)
;; 			  (1+ (previous-single-property-change (point) 'adoc-reserved nil end))
;; 			end)
;; 		      (text-property-any (point) end 'adoc-reserved 'block-del)))
;;       (setq saved-point (point))
;;       (setq found (and (> end2 (point))
;; 		       (re-search-forward regexp end2 t)))

;;       ;; it is prevented if some/any of the must free groups contain text which
;;       ;; has a non-nil adoc-reserved text property
;;       (setq prevented 
;; 	    (and found
;; 		 (some (lambda(x)
;; 			 (and (match-beginning x)
;; 			      (text-property-not-all (match-beginning x)
;; 						     (match-end x)
;; 						     'adoc-reserved nil)))
;; 		       must-free-groups)))
;;       (setq continue
;; 	    (and (or (and found prevented)
;; 		     (and (not found) (< end2 end)))
;; 		 (< (point) (1- end))))
;;       (when continue
;; 	(goto-char (1+ saved-point))))
;;     (and found (not prevented))))

(defun adoc-facespec-subscript ()
  (list 'quote
	(append '(face markup-subscript-face)
		(when (not (= 0 (car adoc-script-raise)))
		  `(display (raise ,(car adoc-script-raise)))))))

(defun adoc-facespec-superscript ()
  (list 'quote
	(append '(face markup-superscript-face)
		(when (not (= 0 (car adoc-script-raise)))
		  `(display (raise ,(cadr adoc-script-raise)))))))

;; todo: use & learn some more macro magic so adoc-kw-unconstrained-quote and
;; adoc-kw-constrained-quote are less redundant and have common parts in one
;; macro. E.g. at least such 'lists'
;; (not (text-property-not-all (match-beginning 1) (match-end 1) 'adoc-reserved nil))
;; (not (text-property-not-all (match-beginning 3) (match-end 3) 'adoc-reserved nil))
;; ...
;; could surely be replaced by a single (adoc-not-reserved-bla-bla 1 3)

;; BUG: Remember that if a matcher function returns nil, font-lock does not
;; further call it and abandons that keyword. Thus in adoc-mode in general,
;; there should be a loop around (and (re-search-forward ...) (not
;; (text-property-not-all...)) ...). Currently if say a constrained quote cant
;; match because of adoc-reserved, following quotes of the same type which
;; should be highlighed are not, because font-lock abandons that keyword.

(defun adoc-kw-one-line-title (level text-face)
  "Creates a keyword for font-lock which highlights one line titles"
  (list
   `(lambda (end) (adoc-kwf-std end ,(adoc-re-one-line-title level) '(0)))
    '(1 '(face markup-meta-hide-face adoc-reserved block-del) t)
    `(2 ,text-face t) 
    '(3  '(face nil adoc-reserved block-del) t)
    '(4 '(face markup-meta-hide-face) t t)))

;; todo: highlight bogous 'two line titles' with warning face
;; todo: completly remove keyword when adoc-enable-two-line-title is nil
(defun adoc-kw-two-line-title (del text-face)
  "Creates a keyword for font-lock which highlights two line titles"
  (list
   ;; matcher function
   `(lambda (end)
      (and adoc-enable-two-line-title
           (re-search-forward ,(adoc-re-two-line-title del) end t)
           (< (abs (- (length (match-string 1)) (length (match-string 2)))) 3)
	   (or (not (numberp adoc-enable-two-line-title))
	       (not (equal adoc-enable-two-line-title (length (match-string 2)))))
           (not (text-property-not-all (match-beginning 0) (match-end 0) 'adoc-reserved nil))))
   ;; highlighers
   `(1 ,text-face t)
   `(2 '(face markup-meta-hide-face adoc-reserved block-del) t)))

(defun adoc-kw-oulisti (type &optional level sub-type)
  "Creates a keyword for font-lock which highlights both (un)ordered list item.
Concerning TYPE, LEVEL and SUB-TYPE see `adoc-re-oulisti'"
  (list
   `(lambda (end) (adoc-kwf-std end ,(adoc-re-oulisti type level sub-type) '(0)))
   '(0 '(face nil adoc-reserved block-del) t)
   '(2 markup-list-face t) 
   '(3 adoc-align t)))

(defun adoc-kw-llisti (sub-type &optional level)
  "Creates a keyword for font-lock which highlights labeled list item.
Concerning TYPE, LEVEL and SUB-TYPE see `adoc-re-llisti'."
  (list
   `(lambda (end)
      (when (adoc-kwf-std end ,(adoc-re-llisti sub-type level) '(0))
	(let ((pos (match-beginning 0)))
	  (when (> pos (point-min))
	    (put-text-property (1- pos) pos 'adoc-reserved 'block-del)))
	t))
   '(1 '(face nil adoc-reserved block-del) t)
   '(2 markup-gen-face t)
   '(3 '(face adoc-align adoc-reserved block-del) t)
   '(4 markup-list-face t)))

(defun adoc-kw-list-continuation ()
  (list 
   ;; see also regexp of forced line break, which is similar. it is not directly
   ;; obvious from asciidoc sourcecode what the exact rules are.
   '(lambda (end) (adoc-kwf-std end "^\\(\\+\\)[ \t]*$" '(1)))
   '(1 '(face markup-meta-face adoc-reserved block-del) t))) 

(defun adoc-kw-delimited-block (del &optional text-face inhibit-text-reserved)
  "Creates a keyword for font-lock which highlights a delimited block."
  (list
   `(lambda (end) (adoc-kwf-std end ,(adoc-re-delimited-block del) '(1 3)))
   '(0 '(face nil font-lock-multiline t) t)
   '(1 '(face markup-meta-hide-face adoc-reserved block-del) t)
   (if (not inhibit-text-reserved)
       `(2 '(face ,text-face face markup-verbatim-face adoc-reserved t) t)
     `(2 ,text-face t))
   '(3 '(face markup-meta-hide-face adoc-reserved block-del) t)))

;; if adoc-kw-delimited-block, adoc-kw-two-line-title don't find the whole
;; delimited block / two line title, at least 'use up' the delimiter line so it
;; is later not misinterpreted as a funny serries of unconstrained quotes
(defun adoc-kw-delimtier-line-fallback ()
  (list
   `(lambda (end) (adoc-kwf-std end ,(adoc-re-delimited-block-line) '(0)))
   '(0 '(face markup-meta-face adoc-reserved block-del) t)))

;; admonition paragraph. Note that there is also the style with the leading attribute list.
;; (?s)^\s*(?P<style>NOTE|TIP|IMPORTANT|WARNING|CAUTION):\s+(?P<text>.+)
(defmacro adoc-kw-admonition-paragraph ()
  "Creates a keyword which highlights admonition paragraphs"
  `(list
    ;; matcher function
    (lambda (end)
      (and (re-search-forward "^[ \t]*\\(\\(?:CAUTION\\|WARNING\\|IMPORTANT\\|TIP\\|NOTE\\):\\)\\([ \t]+\\)" end t)
           (not (text-property-not-all (match-beginning 0) (match-end 0) 'adoc-reserved nil))))
    ;; highlighers
    '(1 '(face adoc-complex-replacement adoc-reserved t))
    '(2 '(face adoc-align adoc-reserved t))))

(defmacro adoc-kw-verbatim-paragraph-sequence ()
  "Creates a keyword which highlights a sequence of verbatim paragraphs."
  `(list
    ;; matcher function
    (lambda (end)
      (and (re-search-forward ,(adoc-re-verbatim-paragraph-sequence) end t)
           (not (text-property-not-all (match-beginning 0) (match-end 0) 'adoc-reserved nil))))
    ;; highlighers
    '(1 '(face adoc-monospace adoc-reserved t font-lock-multiline t))))

(defun adoc-kw-block-title ()
  (list
   `(lambda (end) (adoc-kwf-std end ,(adoc-re-block-title) '(1)))
   '(1 '(face markup-meta-face adoc-reserved block-del))
   '(2 markup-gen-face)
   '(3 '(face nil adoc-reserved block-del))))

(defun adoc-kw-quote (type ldel text-face-spec &optional del-face rdel literal-p)
  "Return a keyword which highlights (un)constrained quotes.
When LITERAL-P is non-nil, the contained text is literal text."
  (list
   ;; matcher function
   `(lambda (end) (adoc-kwf-std end ,(adoc-re-quote type ldel rdel) '(1 2 4) '(3)))
   ;; highlighers
   '(1 '(face markup-meta-face adoc-reserved t) t t)                    ; attribute list
   `(2 '(face ,(or del-face markup-meta-hide-face) adoc-reserved t) t)  ; open del
   `(3 ,text-face-spec append)                                               ; text 
   (if literal-p
	`(3 '(face ,markup-verbatim-face adoc-reserved t) append)
      '(3 nil)) ; grumbl, I dont know how to get rid of it
   `(4 '(face ,(or del-face markup-meta-hide-face) adoc-reserved t) t))); close del

;; bug: escapes are not handled yet
;; todo: give the inserted character a specific face. But I fear that is not
;; possible. The string inserted with the ovlerlay property after-string gets
;; the face of the text 'around' it, which is in this case the text following
;; the replacement.
(defmacro adoc-kw-replacement (regexp &optional replacement)
  "Creates a keyword for font-lock which highlights replacements."
  `(list
    ;; matcher function
    (lambda (end)
      (let ((found t) (prevented t) saved-point)
        (while (and found prevented)
          (setq saved-point (point))
          (setq found
                (re-search-forward ,regexp end t))
          (setq prevented ; prevented is only meaningfull wenn found is non-nil
                (or
                 (not found) ; the following is only needed when found
                 (text-property-not-all (match-beginning 1) (match-end 1) 'adoc-reserved nil)))
          (when (and found prevented)
            (goto-char (+ saved-point 1))))
        (when (and found (not prevented) adoc-insert-replacement ,replacement)
          (let* ((s (cond
                     ((stringp ,replacement)
                      ,replacement)
                     ((functionp ,replacement)
                      (funcall ,replacement (match-string-no-properties 1)))
                     (t (error "Invalid replacement type"))))
                 (o (when (stringp s)
                      (make-overlay (match-end 1) (match-end 1)))))
            (setq adoc-replacement-failed (not o))
            (unless adoc-replacement-failed
              (overlay-put o 'after-string s))))
        (and found (not prevented))))

    ;; highlighers
    ;; todo: replacement instead warining face if resolver is not given
    (if (and adoc-insert-replacement ,replacement)
        ;; '((1 (if adoc-replacement-failed adoc-warning adoc-hide-delimiter) t)
        ;;   (1 '(face nil adoc-reserved t) t))
        '(1 '(face adoc-hide-delimiter adoc-reserved t) t)
      '(1 '(face adoc-replacement adoc-reserved t) t))))

;; - To ensure that indented lines are nicely aligned. They only look aligned if
;;   the whites at line beginning have a fixed with font.
;; - Some faces have properties which are also visbile on whites
;;   (underlines/backgroundcolor/...), for example links typically gave
;;   underlines. If now a link in an indented paragraph (e.g. because its a list
;;   item), spawns multiple lines, then without countermeasures the blanks at
;;   line beginning would also be underlined, which looks akward.
(defun adoc-flf-first-whites-fixed-width(end)
  ;; it makes no sense to do something with a blank line, so require at least one non blank char. 
  (and (re-search-forward "\\(^[ \t]+\\)[^ \t\n]" end t)
       ;; dont replace a face with with adoc-align which already is a fixed with
       ;; font (most probably), because then it also won't look aligned
       (text-property-not-all (match-beginning 1) (match-end 1) 'face 'markup-typewriter-face)
       (text-property-not-all (match-beginning 1) (match-end 1) 'face 'markup-code-face)
       (text-property-not-all (match-beginning 1) (match-end 1) 'face 'markup-passthrough-face)
       (text-property-not-all (match-beginning 1) (match-end 1) 'face 'markup-comment-face)))

;; See adoc-flf-first-whites-fixed-width
(defun adoc-kw-first-whites-fixed-width ()
  (list
   'adoc-flf-first-whites-fixed-width
   '(1 adoc-align t)))

;; ensures that faces from the markup-text group don't overwrite faces from the
;; markup-meta group
(defun adoc-flf-meta-face-cleanup (end)
  (while (< (point) end)
    (let* ((next-pos (next-single-property-change (point) 'face nil end))
	   (faces-raw (get-text-property (point) 'face))
	   (faces (if (listp faces-raw) faces-raw (list faces-raw)))
	   newfaces
	   meta-p)
      (while faces
	(if (member (car faces) '(markup-meta-hide-face markup-command-face markup-attribute-face markup-value-face markup-complex-replacement-face markup-list-face markup-table-face markup-table-row-face markup-table-cell-face markup-anchor-face markup-internal-reference-face markup-comment-face markup-preprocessor-face))
	    (progn
	      (setq meta-p t)
	      (setq newfaces (cons (car faces) newfaces)))
	  (if (not (string-match "markup-" (symbol-name (car faces))))
	      (setq newfaces (cons (car faces) newfaces))))
	(setq faces (cdr faces)))
      (if meta-p
	  (put-text-property (point) next-pos 'face
			     (if (= 1 (length newfaces)) (car newfaces) newfaces)))
      (goto-char next-pos)))
  nil)

(defun adoc-unfontify-region-function (beg end) 
  ;; 
  (font-lock-default-unfontify-region beg end)
  
  ;; remove overlays. Currently only used by AsciiDoc replacements
  ;; todo: this is an extremly brute force solution and interacts very badly
  ;; with many (minor) modes using overlays such as flyspell or ediff
  (when adoc-insert-replacement
    (remove-overlays beg end))

  ;; text properties. Currently only display raise used for sub/superscripts.
  ;; code snipped copied from tex-mode
  (when (not (and (= 0 (car adoc-script-raise)) (= 0 (cadr adoc-script-raise))))
    (while (< beg end)
      (let ((next (next-single-property-change beg 'display nil end))
	    (prop (get-text-property beg 'display)))
	(if (and (eq (car-safe prop) 'raise)
		 (member (car-safe (cdr prop)) adoc-script-raise)
		 (null (cddr prop)))
	    (put-text-property beg next 'display nil))
	(setq beg next)))))

(defun adoc-font-lock-mark-block-function ()
  (mark-paragraph 2)
  (forward-paragraph -1))

(defun adoc-get-font-lock-keywords ()
  (list
   
   ;; Asciidoc BUG: Lex.next has a different order than the following extract
   ;; from the documentation states.
   
   ;; When a block element is encountered asciidoc(1) determines the type of
   ;; block by checking in the following order (first to last): (section)
   ;; Titles, BlockMacros, Lists, DelimitedBlocks, Tables, AttributeEntrys,
   ;; AttributeLists, BlockTitles, Paragraphs.

   ;; sections / document structure
   ;; ------------------------------
   (adoc-kw-one-line-title 0 markup-title-0-face)
   (adoc-kw-one-line-title 1 markup-title-1-face)
   (adoc-kw-one-line-title 2 markup-title-2-face)
   (adoc-kw-one-line-title 3 markup-title-3-face)
   (adoc-kw-one-line-title 4 markup-title-4-face)
   (adoc-kw-two-line-title (nth 0 adoc-two-line-title-del) markup-title-0-face)
   (adoc-kw-two-line-title (nth 1 adoc-two-line-title-del) markup-title-1-face)
   (adoc-kw-two-line-title (nth 2 adoc-two-line-title-del) markup-title-2-face)
   (adoc-kw-two-line-title (nth 3 adoc-two-line-title-del) markup-title-3-face)
   (adoc-kw-two-line-title (nth 4 adoc-two-line-title-del) markup-title-4-face)


   ;; block macros 
   ;; ------------------------------
   ;; todo: respect asciidoc.conf order

   ;; -- system block macros
   ;;     # Default system macro syntax.
   ;; SYS_RE = r'(?u)^(?P<name>[\\]?\w(\w|-)*?)::(?P<target>\S*?)' + \
   ;;          r'(\[(?P<attrlist>.*?)\])$'
   ;; conditional inclusion
   (list "^\\(\\(?:ifn?def\\|endif\\)::\\)\\([^ \t\n]*?\\)\\(\\[\\).+?\\(\\]\\)[ \t]*$"
         '(1 '(face adoc-preprocessor adoc-reserved block-del))    ; macro name
         '(2 '(face adoc-delimiter adoc-reserved block-del))       ; condition
         '(3 '(face adoc-hide-delimiter adoc-reserved block-del))  ; [
         ; ... attribute list content = the conditionaly included text
         '(4 '(face adoc-hide-delimiter adoc-reserved block-del))) ; ]
   ;; include
   (list "^\\(\\(include1?::\\)\\([^ \t\n]*?\\)\\(\\[\\)\\(.*?\\)\\(\\]\\)\\)[ \t]*$"
         '(1 '(face nil adoc-reserved block-del)) ; the whole match
         '(2 adoc-preprocessor)           ; macro name
         '(3 adoc-delimiter)              ; file name
         '(4 adoc-hide-delimiter)         ; [
         '(5 adoc-delimiter)              ;   attribute list content
         '(6 adoc-hide-delimiter))        ; ]


   ;; -- special block macros
   ;; ruler line.
   ;; Is a block marcro in asciidoc.conf, altough manual has it in the "text formatting" section 
   ;; ^'{3,}$=#ruler
   (list "^\\('\\{3,\\}+\\)[ \t]*$"
         '(1 '(face adoc-complex-replacement adoc-reserved block-del))) 
   ;; forced pagebreak
   ;; Is a block marcro in asciidoc.conf, altough manual has it in the "text formatting" section 
   ;; ^<{3,}$=#pagebreak
   (list "^\\(<\\{3,\\}+\\)[ \t]*$"
         '(1 '(face adoc-delimiter adoc-reserved block-del))) 
   ;; comment
   ;; (?mu)^[\\]?//(?P<passtext>[^/].*|)$
   ;; I don't know what the [\\]? should mean
   (list "^\\(//\\(?:[^/].*\\|\\)\n\\)"
         '(1 '(face markup-comment-face adoc-reserved block-del)))    
   ;; image
   ;; (?u)^(?P<name>image|unfloat)::(?P<target>\S*?)(\[(?P<attrlist>.*?)\])$
   (list "^\\(\\(image::\\)\\([^ \t\n]*?\\)\\(\\[.*?\\]\\)\\)[ \t]*$"
         '(1 '(face nil adoc-reserved block-del)) ; whole match
         '(2 adoc-hide-delimiter)         ; macro name
         '(3 adoc-complex-replacement)    ; file name
         '(4 adoc-delimiter))             ; attribute list inlcl. []
   ;; passthrough: (?u)^(?P<name>pass)::(?P<subslist>\S*?)(\[(?P<passtext>.*?)\])$
   ;; todo

   ;; -- general block macro
   ;; also highlight yet unknown block macros
   ;; general syntax: (?u)^(?P<name>image|unfloat)::(?P<target>\S*?)(\[(?P<attrlist>.*?)\])$
   (list "^[a-zA-Z0-9_]+::\\([^ \t\n]*?\\)\\(\\[.*?\\]\\)[ \t]*$"
         'adoc-delimiter) 


   ;; lists
   ;; ------------------------------
   ;; todo: respect and insert adoc-reserved
   ;; 
   ;; bug: for items begining with a label (i.e. user text): if might be that
   ;; the label contains a bogous end delimiter such that you get a
   ;; highlighting that starts in the line before the label item and ends
   ;; within the label. Example:
   ;;
   ;; bla bli 2 ** 8 is 256                   quote starts at this **
   ;; that is **important**:: bla bla         ends at the first **
   ;; 
   ;; similary:
   ;;
   ;; bla 2 ** 3:: bla bla 2 ** 3 gives       results in an untwanted unconstrained quote
   ;; 
   ;; - dsfadsf sdf ** asfdfsad
   ;; - asfdds fsda ** fsfas
   ;;
   ;; maybe the solution is invent a new value for adoc-reserved, or a new
   ;; property alltogether. That would also be used for the trailing \n in other
   ;; block elements. Text is not allowed to contain them. All font lock
   ;; keywords standing for asciidoc inline substituions would have to be
   ;; adapted.
   ;;
   ;;
   ;; bug: the text of labelleled items gets inline macros such as anchor not
   ;; highlighted. See for example [[X80]] in asciidoc manual source.
   (adoc-kw-oulisti 'adoc-unordered 'adoc-all-levels) 
   (adoc-kw-oulisti 'adoc-unordered nil 'adoc-bibliography) 
   (adoc-kw-oulisti 'adoc-explicitly-numbered ) 
   (adoc-kw-oulisti 'adoc-implicitly-numbered 'adoc-all-levels) 
   (adoc-kw-oulisti 'adoc-callout) 
   (adoc-kw-llisti 'adoc-labeled-normal 0) 
   (adoc-kw-llisti 'adoc-labeled-normal 1) 
   (adoc-kw-llisti 'adoc-labeled-normal 2) 
   (adoc-kw-llisti 'adoc-labeled-normal 3) 
   (adoc-kw-llisti 'adoc-labeled-qanda) 
   (adoc-kw-llisti 'adoc-labeled-glossary) 
   (adoc-kw-list-continuation) 

   ;; Delimited blocks
   ;; ------------------------------
   (adoc-kw-delimited-block 0 markup-comment-face)   ; comment
   (adoc-kw-delimited-block 1 markup-passthrough-face) ; passthrough
   (adoc-kw-delimited-block 2 markup-code-face) ; listing
   (adoc-kw-delimited-block 3 markup-verbatim-face) ; literal
   (adoc-kw-delimited-block 4 nil t) ; quote    
   (adoc-kw-delimited-block 5 nil t) ; example  
   (adoc-kw-delimited-block 6 adoc-secondary-text t) ; sidebar
   (adoc-kw-delimited-block 7 nil t) ; open block
   (adoc-kw-delimtier-line-fallback)  


   ;; tables
   ;; ------------------------------
   ;; must come BEFORE block title, else rows starting like .2+| ... | ... are taken as 
   (cons "^|=\\{3,\\}[ \t]*$" 'adoc-table-del ) ; ^\|={3,}$
   (list (concat "^"                  "\\(" (adoc-re-cell-specifier) "\\)" "\\(|\\)"
                 "\\(?:[^|\n]*?[ \t]" "\\(" (adoc-re-cell-specifier) "\\)" "\\(|\\)"
                 "\\(?:[^|\n]*?[ \t]" "\\(" (adoc-re-cell-specifier) "\\)" "\\(|\\)"
                 "\\(?:[^|\n]*?[ \t]" "\\(" (adoc-re-cell-specifier) "\\)" "\\(|\\)" "\\)?\\)?\\)?")
         '(1 '(face adoc-delimiter adoc-reserved block-del) nil t) '(2 '(face adoc-table-del adoc-reserved block-del) nil t)
         '(3 '(face adoc-delimiter adoc-reserved block-del) nil t) '(4 '(face adoc-table-del adoc-reserved block-del) nil t)
         '(5 '(face adoc-delimiter adoc-reserved block-del) nil t) '(6 '(face adoc-table-del adoc-reserved block-del) nil t)
         '(7 '(face adoc-delimiter adoc-reserved block-del) nil t) '(8 '(face adoc-table-del adoc-reserved block-del) nil t))
   

   ;; attribute entry
   ;; ------------------------------
   (list (adoc-re-attribute-entry) '(1 adoc-delimiter) '(2 adoc-secondary-text nil t))


   ;; attribute list
   ;; ----------------------------------

   ;; --- special attribute lists
   ;; quote/verse
   (list (concat
          "^\\("
            "\\(\\[\\)"
            "\\(quote\\|verse\\)"
            "\\(?:\\(,\\)\\(.*?\\)\\(?:\\(,\\)\\(.*?\\)\\)?\\)?"
            "\\(\\]\\)"
          "\\)[ \t]*$")
         '(1 '(face nil adoc-reserved block-del)) ; whole match
         '(2 adoc-hide-delimiter)         ; [
         '(3 adoc-delimiter)              ;   quote|verse
         '(4 adoc-hide-delimiter nil t)   ;   ,
         '(5 adoc-secondary-text nil t)   ;   attribution(author)
         '(6 adoc-delimiter nil t)        ;   ,
         '(7 adoc-secondary-text nil t)   ;   cite title
         '(8 adoc-hide-delimiter))        ; ]
   ;; admonition block
   (list "^\\(\\[\\(?:CAUTION\\|WARNING\\|IMPORTANT\\|TIP\\|NOTE\\)\\]\\)[ \t]*$"
         '(1 '(face adoc-complex-replacement adoc-reserved block-del)))
   ;; block id = 1st alternation from asciidoc's regex (see general section below)
   ;; see also anchor inline macro
   (list "^\\(\\(\\[\\[\\)\\([-a-zA-Z0-9_]+\\)\\(?:\\(,\\)\\(.*?\\)\\)?\\(\\]\\]\\)[ \t]*\\)$"
         '(1 '(face nil adoc-reserved block-del)) ; whole match
         '(2 adoc-hide-delimiter)         ; [[
         '(3 adoc-anchor)                 ;   anchor-id
         '(4 adoc-hide-delimiter nil t)   ;   ,
         '(5 adoc-secondary-text nil t)   ;   xref text
         '(6 adoc-hide-delimiter))        ; ]]

   ;; --- general attribute list = 2nd alternation from ascidoc's regex
   ;; (?u)(^\[\[(?P<id>[\w\-_]+)(,(?P<reftext>.*?))?\]\]$)|(^\[(?P<attrlist>.*)\]$)
   (list "^\\(\\[.*\\]\\)[ \t]*$"
         '(1 '(face adoc-delimiter adoc-reserved block-del)))


   ;; block title
   ;; -----------------------------------
   (adoc-kw-block-title)


   ;; paragraphs
   ;; --------------------------
   (adoc-kw-verbatim-paragraph-sequence)
   (adoc-kw-admonition-paragraph)
   (list "^[ \t]+$" '(0 '(face nil adoc-reserved block-del) t))

   ;; Inline substitutions
   ;; ==========================================
   ;; Inline substitutions within block elements are performed in the
   ;; following default order:
   ;; -. Passtrough stuff removal (seen in asciidoc source)
   ;; 1. Special characters
   ;; 2. Quotes
   ;; 3. Special words
   ;; 4. Replacements
   ;; 5. Attributes
   ;; 6. Inline Macros
   ;; 7. Replacements2


   ;; (passthrough stuff removal)
   ;; ------------------------
   ;; todo. look in asciidoc source how exactly asciidoc does it
   ;; 1) BUG: actually only ifdef::no-inline-literal[]
   ;; 2) TODO: in asciidod.conf (but not yet here) also in inline macro section

   ;; AsciiDoc Manual: constitutes an inline literal passthrough. The enclosed
   ;; text is rendered in a monospaced font and is only subject to special
   ;; character substitution.
   (adoc-kw-quote 'adoc-constrained "`" markup-typewriter-face nil nil t)     ;1)
   ;; AsciiDoc Manual: The triple-plus passthrough is functionally identical to
   ;; the pass macro but you don’t have to escape ] characters and you can
   ;; prefix with quoted attributes in the inline version
   (adoc-kw-quote 'adoc-unconstrained "+++" markup-typewriter-face nil nil t) ;2)
   ;;The double-dollar passthrough is functionally identical to the triple-plus
   ;;passthrough with one exception: special characters are escaped.
   (adoc-kw-quote 'adoc-unconstrained "$$" markup-typewriter-face nil nil t)  ;2)

   ;; special characters
   ;; ------------------
   ;; no highlighting for them, since they are a property of the backend markup,
   ;; not of AsciiDoc syntax


   ;; quotes: unconstrained and constrained
   ;; order given by asciidoc.conf
   ;; ------------------------------
   (adoc-kw-quote 'adoc-unconstrained "**" markup-strong-face)
   (adoc-kw-quote 'adoc-constrained "*" markup-strong-face)
   (adoc-kw-quote 'adoc-constrained "``" nil adoc-replacement "''") ; double quoted text
   (adoc-kw-quote 'adoc-constrained "'" markup-emphasis-face)	   ; single quoted text
   (adoc-kw-quote 'adoc-constrained "`" nil adoc-replacement "'")
   ;; `...` , +++...+++, $$...$$ are within passthrough stuff above
   (adoc-kw-quote 'adoc-unconstrained "++" markup-typewriter-face) ; AsciiDoc manual: really onl '..are rendered in a monospaced font.'
   (adoc-kw-quote 'adoc-constrained "+" markup-typewriter-face) 
   (adoc-kw-quote 'adoc-unconstrained  "__" markup-emphasis-face)
   (adoc-kw-quote 'adoc-constrained "_" markup-emphasis-face)
   (adoc-kw-quote 'adoc-unconstrained "##" markup-gen-face) ; unquoted text
   (adoc-kw-quote 'adoc-constrained "#" markup-gen-face)    ; unquoted text
   (adoc-kw-quote 'adoc-unconstrained "~" (adoc-facespec-subscript)) ; subscript
   (adoc-kw-quote 'adoc-unconstrained "^" (adoc-facespec-superscript)) ; superscript
    

   ;; special words
   ;; --------------------
   ;; there are no default special words to highlight


   ;; replacements
   ;; --------------------------------
   ;; Asciidoc.conf surounds em dash with thin spaces. I think that does not
   ;; make sense here, all that spaces you would see in the buffer would at best
   ;; be confusing.
   (adoc-kw-replacement "\\((C)\\)" "\u00A9")
   (adoc-kw-replacement "\\((R)\\)" "\u00AE")
   (adoc-kw-replacement "\\((TM)\\)" "\u2122")
   ;; (^-- )=&#8212;&#8201;
   ;; (\n-- )|( -- )|( --\n)=&#8201;&#8212;&#8201;
   ;; (\w)--(\w)=\1&#8212;\2
   (adoc-kw-replacement "^\\(--\\)[ \t]" "\u2014") ; em dash. See also above
   (adoc-kw-replacement "[ \t]\\(--\\)\\(?:[ \t]\\|$\\)" "\u2014") ; dito
   (adoc-kw-replacement "[a-zA-Z0-9_]\\(--\\)[a-zA-Z0-9_]" "\u2014") ; dito
   (adoc-kw-replacement "[a-zA-Z0-9_]\\('\\)[a-zA-Z0-9_]" "\u2019") ; punctuation apostrophe
   (adoc-kw-replacement "\\(\\.\\.\\.\\)" "\u2026") ; ellipsis
   (adoc-kw-replacement "\\(->\\)" "\u2192")
   (adoc-kw-replacement "\\(=>\\)" "\u21D2")
   (adoc-kw-replacement "\\(<-\\)" "\u2190")
   (adoc-kw-replacement "\\(<=\\)" "\u21D0") 
   ;; general character entity reference
   ;; (?<!\\)&amp;([:_#a-zA-Z][:_.\-\w]*?;)=&\1
   (adoc-kw-replacement "\\(&[:_#a-zA-Z]\\(?:[-:_.]\\|[a-zA-Z0-9_]\\)*?;\\)" 'adoc-entity-to-string)

   ;; attributes
   ;; ---------------------------------
   ;; attribute refrence
   (cons "{\\(\\w+\\(?:\\w*\\|-\\)*\\)\\([=?!#%@$][^}\n]*\\)?}" 'adoc-replacement) 


   ;; inline macros (that includes anchors, links, footnotes,....)
   ;; ------------------------------
   ;; todo: make adoc-kw-... macros to have less redundancy
   ;; Note: Some regexp/kewyords are within the macro section 
   ;; TODO:
   ;; - allow multiline
   ;; - currently escpapes are not looked at
   ;; - adapt to the adoc-reserved scheme
   ;; - same order as in asciidoc.conf (is that in 'reverse'? cause 'default syntax' comes first)
   ;; 
   ;; 

   ;; # These URL types don't require any special attribute list formatting.
   ;; (?su)(?<!\S)[\\]?(?P<name>http|https|ftp|file|irc):(?P<target>//[^\s<>]*[\w/])=
   ;; # Allow a leading parenthesis and square bracket.
   ;; (?su)(?<\=[([])[\\]?(?P<name>http|https|ftp|file|irc):(?P<target>//[^\s<>]*[\w/])=
   ;; # Allow <> brackets.
   ;; (?su)[\\]?&lt;(?P<name>http|https|ftp|file|irc):(?P<target>//[^\s<>]*[\w/])&gt;=
   ;; todo: overtake above regexes
   ;; asciidoc.conf bug? why is it so restrictive for urls without attribute
   ;; list, that version can only have a limited set of characters before. Why
   ;; not just have the rule that it must start with \b.
   (list "\\b\\(\\(?:https?\\|ftp\\|file\\|irc\\|mailto\\|callto\\|link\\)[^ \t\n]*?\\)\\(\\[\\)\\(.*?\\)\\(,.*?\\)?\\(\\]\\)"
         '(1 adoc-delimiter) '(2 adoc-hide-delimiter)  '(3 adoc-reference) '(4 adoc-delimiter nil t) '(5 adoc-hide-delimiter))
   (cons "\\b\\(?:https?\\|ftp\\|file\\|irc\\)://[^ \t<>\n]*[a-zA-Z0-9_//]" 'adoc-reference)
   (list "\\b\\(xref:\\)\\([^ \t\n]*?\\)\\(\\[\\)\\(.*?\\)\\(,.*?\\)?\\(\\]\\)"
         '(1 adoc-hide-delimiter) '(2 adoc-delimiter) '(3 adoc-hide-delimiter) '(4 adoc-reference) '(5 adoc-delimiter nil t) '(6 adoc-hide-delimiter)) 

   ;; todo: fontify alt and title attribute value
   ;; todo: one regexp for both inline/block image macro
   ;;          1           2       3               4     5           6             7              8          9
   (list "\\b\\(image:\\)\\(:?\\)\\([^ \t\n]*?\\)\\(\\[\\(\"?\\)\\)\\([^=\n]*?\\)\\(\\5[ \t]*,\\)\\(.*?\\)?\\(\\]\\)"
         '(1 adoc-hide-delimiter)       ; macro name
         '(2 adoc-warning)              ; if there are two colons, we have a bogous block macro
         '(3 adoc-complex-replacement)  ; file name
         '(4 adoc-hide-delimiter)       ; ["
         '(6 adoc-secondary-text)       ;    first positional argument is caption
         '(7 adoc-hide-delimiter)       ;    ",
         '(8 adoc-delimiter nil t)      ;    rest of attribute list
         '(9 adoc-hide-delimiter))      ; ]
   (list "\\b\\(image:\\)\\(:?\\)\\([^ \t\n]*?\\)\\(\\[\\)\\(.*?\\)\\(\\]\\)"
         '(1 adoc-hide-delimiter)       ; macro name
         '(2 adoc-warning)              ; if there are two colons, we have a bogous block macro
         '(3 adoc-complex-replacement)  ; file name
         '(4 adoc-hide-delimiter)       ; [
         '(5 adoc-delimiter)            ;   attribute list content
         '(6 adoc-hide-delimiter))      ; ]

   (list "\\(anchor:\\)\\([^ \t\n]*?\\)\\(\\[\\)\\(.*?\\)\\(,.*?\\)?\\(\]\\)"
         '(1 adoc-hide-delimiter) '(2 adoc-anchor) '(3 adoc-hide-delimiter) '(4 adoc-secondary-text) '(5 adoc-delimiter nil t) '(6 adoc-hide-delimiter)) 
   ;; standalone email, SIMPLE reglex! copied from http://www.regular-expressions.info/email.html
   ;; asciidoc.conf: (?su)(?<![">:\w._/-])[\\]?(?P<target>\w[\w._-]*@[\w._-]*\w)(?!["<\w_-])=mailto
   ;; todo: use asciidoc's regex
   (cons "\\(\\w\\|[.%+-]\\)+@\\(\\w\\|[.-]\\)+\\.[a-zA-Z]\\{2,4\\}" 'adoc-reference) 

   (list "\\(\\bfootnote:\\)\\(\\[\\)\\(.*?\\(?:\n.*?\\)?\\)\\(\\]\\)"
         '(1 adoc-delimiter)            ; name
         '(2 adoc-hide-delimiter)       ; [
         '(3 adoc-secondary-text)       ; footnote text
         '(4 adoc-hide-delimiter))      ; ]
   (list "\\(\\bfootnoteref:\\)\\(\\[\\)\\(.*?\\)\\(,\\)\\(.*?\\(?:\n.*?\\)?\\)\\(\\]\\)"
         '(1 adoc-delimiter)            ; name
         '(2 adoc-hide-delimiter)       ; [
         '(3 adoc-anchor)               ; anchor-id
         '(4 adoc-hide-delimiter)       ; ,
         '(5 adoc-secondary-text)       ; footnote text
         '(6 adoc-hide-delimiter))      ; ]
   (list "\\(\\bfootnoteref:\\)\\(\\[\\)\\([^,\n].*?\\(?:\n.*?\\)?\\)\\(\\]\\)"
         '(1 adoc-delimiter)            ; name
         '(2 adoc-hide-delimiter)       ; [
         '(3 adoc-reference)            ; reference-id to footnote
         ;; '(3 (adoc-facespec-superscript)) bug: does also fontify the version having anchor-id
         '(4 adoc-hide-delimiter))      ; ]


   ;; index terms
   ;; todo:
   ;; - copy asciidocs regexps below
   ;; - add the indexterm2?:...[...] syntax     
   ;; ifdef::asciidoc7compatible[]
   ;;   (?su)(?<!\S)[\\]?\+\+(?P<attrlist>[^+].*?)\+\+(?!\+)=indexterm
   ;;   (?<!\S)[\\]?\+(?P<attrlist>[^\s\+][^+].*?)\+(?!\+)=indexterm2
   ;; ifndef::asciidoc7compatible[]
   ;;   (?su)(?<!\()[\\]?\(\(\((?P<attrlist>[^(].*?)\)\)\)(?!\))=indexterm
   ;;   (?<!\()[\\]?\(\((?P<attrlist>[^\s\(][^(].*?)\)\)(?!\))=indexterm2
   ;; 
   (cons "(((?\\([^\\\n]\\|\\\\.\\)*?)))?" 'adoc-delimiter) 

   ;; passthrough. Note that quote section has some of them also
   ;; todo: passthrough stuff
   ;; (?su)[\\]?(?P<name>pass):(?P<subslist>\S*?)\[(?P<passtext>.*?)(?<!\\)\]=[]
   ;; (?su)[\\]?\+\+\+(?P<passtext>.*?)\+\+\+=pass[]
   ;; (?su)[\\]?\$\$(?P<passtext>.*?)\$\$=pass[specialcharacters]
   ;; # Inline literal (within ifndef::no-inline-literal[])
   ;; (?su)(?<!\w)([\\]?`(?P<passtext>\S|\S.*?\S)`)(?!\w)=literal[specialcharacters]

   ;; -- anchors, references, biblio
   ;;
   ;; anchor inline macro with xreflabel (see also block id block macro)
   ;; (?su)[\\]?\[\[(?P<attrlist>[\w"].*?)\]\]=anchor2
   (list "\\(\\[\\[\\)\\([a-zA-Z0-9_\"].*?\\)\\(,\\)\\(.*?\\)\\(\]\\]\\)"
         '(1 adoc-hide-delimiter)       ; [[
         '(2 adoc-anchor)               ; anchor-id
         '(3 adoc-hide-delimiter)       ; ,
         '(4 adoc-secondary-text)       ; xref label
         '(5 adoc-hide-delimiter))      ; ]]
   ;; anchor inline macro without xreflabel (see also block id block macro)
   ;; (?su)[\\]?\[\[(?P<attrlist>[\w"].*?)\]\]=anchor2
   (list "\\(\\[\\[\\)\\([a-zA-Z0-9_\"].*?\\)\\(\\]\\]\\)"
         '(1 adoc-hide-delimiter)       ; [[
         '(2 adoc-anchor)               ; anchor-id
         '(3 adoc-hide-delimiter))      ; ]]
   ;; reference with own/explicit caption
   ;; (?su)[\\]?&lt;&lt;(?P<attrlist>[\w"].*?)&gt;&gt;=xref2
   (list "\\(<<\\)\\([a-zA-Z0-9\"].*?\\)\\(,\\)\\(.*?\\(?:\n.*?\\)??\\)\\(>>\\)"
         '(1 adoc-hide-delimiter)       ; <<
         '(2 adoc-delimiter)            ; anchor-id
         '(3 adoc-hide-delimiter)       ; ,
         '(4 adoc-reference)            ; link text
         '(5 adoc-hide-delimiter))      ; >>
   ;; reference without caption
   ;; asciidoc.conf uses the same regexp as for without caption
   (list "\\(<<\\)\\([a-zA-Z0-9\"].*?\\(?:\n.*?\\)??\\)\\(>>\\)"
         '(1 adoc-hide-delimiter)       ; <<
         '(2 adoc-reference)            ; link text = anchor id
         '(3 adoc-hide-delimiter))      ; >>
   ;; biblio item:
   ;; (?su)[\\]?\[\[\[(?P<attrlist>[\w][\w-]*?)\]\]\]=anchor3
   (list "\\(\\[\\[\\)\\(\\[[a-zA-Z0-9_][-a-zA-Z0-9_]*?\\]\\)\\(\\]\\]\\)"
         '(1 adoc-hide-delimiter)       ; [[
         '(2 adoc-generic)              ; [anchorid]
         '(3 adoc-hide-delimiter))      ; ]]

   ;; -- general inline
   ;; inline: (?su)[\\]?(?P<name>\w(\w|-)*?):(?P<target>\S*?)\[(?P<passtext>.*?)(?<!\\)\]=
   ;; todo: implement my regexp according the one above from asciidoc.conf
   (cons "\\\\?\\w\\(\\w\\|-\\)*:[^ \t\n]*?\\[.*?\\]" 'adoc-delimiter) ; inline

   ;; -- forced linebreak 
   ;; manual: A plus character preceded by at least one space character at the
   ;; end of a non-blank line forces a line break.
   ;; Asciidoc bug: If has that affect also on a non blank line.
   ;; todo: what kind of element is that? Really text formatting? Its not in asciidoc.conf
   (list "^.*[^ \t\n].*[ \t]\\(\\+\\)[ \t]*$" '(1 adoc-delimiter)) ; bug: only if not adoc-reserved

   ;; -- callout anchors (references are within list)
   ;; commented out because they are only witin (literal?) blocks
   ;; asciidoc.conf: [\\]?&lt;(?P<index>\d+)&gt;=callout
   ;; (list "^\\(<\\)\\([0-9+]\\)\\(>\\)" '(1 adoc-delimiter) '(3 adoc-delimiter))


   ;; Replacements2
   ;; -----------------------------
   ;; there default replacements2 section is empty


   ;; misc 
   ;; ------------------------------

   ;; -- misc 
   ;; special attribute type-value pairs: 
   ;; bug: can actually only appear within attribute lists
   (list "\\[[^]\n]*?\\(?:caption\\|title\\|alt\\|attribution\\|citetitle\\|xreflabel\\|xreftext\\)=\"\\([^\"\n]*?\\)\"[^]\n]*?\\]"
         '(1 adoc-secondary-text t)) 
   (list "\\[[^]\n]*?\\(?:id\\)=\"\\([^\"\n]*?\\)\"[^]\n]*?\\]"
         '(1 adoc-anchor t)) 
   (adoc-kw-first-whites-fixed-width)

   ;; -- warnings 
   ;; todo: add tooltip explaining what is the warning all about
   ;; bogous 'list continuation'
   (list "^\\([ \t]+\\+[ \t]*\\)$" '(1 adoc-warning t)) 
   ;; list continuation witch appends a literal paragraph. The user probably
   ;; wanted to add a normal paragraph. List paragraphs are appended
   ;; implicitely.
   (list "^\\(\\+[ \t]*\\)\n\\([ \t]+\\)[^ \t\n]" '(1 adoc-warning t) '(2 adoc-warning t)) 

   ;; cleanup
   (list 'adoc-flf-meta-face-cleanup)
   ))

(defun adoc-show-version ()
  "Show the version number in the minibuffer."
  (interactive)
  (message "adoc-mode, version %s" adoc-mode-version))

(defun adoc-goto-ref-label ()
  "Goto the label/anchor refered to by the reference at/before point.
Works only for references in the <<id[,reftex]>> style and
anchors in the [[id]] style."
  (interactive)
  (push-mark)
  (cond
   ((looking-at "<<")
    ) ; nop
   ((looking-at "<")
    (backward-char 1))
   (t
    (unless (re-search-backward "<<" (line-beginning-position) t)
      (error "Line contains no reference at/before point"))))
  (re-search-forward "<<\\(.*?\\)[ \t]*\\(?:,\\|>>\\)")
  (goto-char 0)
  (re-search-forward (concat "^\\[\\[" (match-string 1) "\\]\\]")))

(defun adoc-title-descriptor()
  "Returns title descriptor of title point is in.

Title descriptor looks like this: (TYPE SUB-TYPE LEVEL TEXT START END)

0 TYPE: 1 fore one line title, 2 for two line title.

1 SUB-TYPE: Only applicable for one line title: 1 for only
starting delimiter ('== my title'), 2 for both starting and
trailing delimiter ('== my title ==').

2 LEVEL: Level of title. A value between 0 and
`adoc-title-max-level' inclusive.

3 TEXT: Title's text

4 START / 5 END: Start/End pos of match"
  (save-excursion 
    (let ((level 0)
          found
          type sub-type text)
      (beginning-of-line)
      (while (and (not found) (<= level adoc-title-max-level))
        (cond
         ((looking-at (adoc-re-one-line-title level))
          (setq type 1)
          (setq text (match-string 2))
          (setq sub-type (if (< 0 (length (match-string 3))) 2 1))
          (setq found t))
         ;; WARNING: if you decide to replace adoc-re-two-line-title with a
         ;; method ensuring the correct length of the underline, be aware that
         ;; due to adoc-adjust-title-del we sometimes want to find a title which has
         ;; the wrong underline length.
         ((looking-at (adoc-re-two-line-title (nth level adoc-two-line-title-del)))
          (setq type 2)
          (setq text (match-string 1))
          (setq found t))
         (t
          (setq level (+ level 1)))))        
      (when found
        (list type sub-type level text (match-beginning 0) (match-end 0))))))

(defun adoc-make-title(descriptor)
  (let ((type (nth 0 descriptor))
        (sub-type (nth 1 descriptor))
        (level (nth 2 descriptor))
        (text (nth 3 descriptor)))
    (if (eq type 1)
        (adoc-make-one-line-title sub-type level text)
      (adoc-make-two-line-title (nth level adoc-two-line-title-del) text))))

(defun adoc-modify-title (&optional new-level-rel new-level-abs new-type new-sub-type create)
  "Modify properties of title point is on.

NEW-LEVEL-REL defines the new title level relative to the current
one. Negative values are allowed. 0 or nil means don't change.
NEW-LEVEL-ABS defines the new level absolutely. When both
NEW-LEVEL-REL and NEW-LEVEL-ABS are non-nil, NEW-LEVEL-REL takes
precedence. When both are nil, level is not affected.

When ARG is nil, it defaults to 1. When ARG is negative, level is
denoted that many levels. If ARG is 0, see `adoc-adjust-title-del'.

When NEW-TYPE is nil, the title type is unaffected. If NEW-TYPE
is t, the type is toggled. If it's 1 or 2, the new type is one
line title or two line title respectively.

NEW-SUB-TYPE is analogous to NEW-TYPE. However when the actual
title has no sub type, only the absolute values of NEW-SUB-TYPE
apply, otherise the new sub type becomes
`adoc-default-title-sub-type'.

If CREATE is nil, an error is signaled if point is not on a
title. If CREATE is non-nil a new title is created if point is
currently not on a title.

BUG: In one line title case: number of spaces between delimiters
and title's text are not preserved, afterwards its always one space."
  (let ((descriptor (adoc-title-descriptor)))
    (if (or create (not descriptor))
        (error "Point is not on a title"))
    ;; todo: set descriptor to default
    ;; (if (not descriptor)
    ;;     (setq descriptor (list 1 1 2 ?? adoc-default-title-type adoc-default-title-sub-type)))
    (let* ((type (nth 0 descriptor))
           (new-type-val (cond
                      ((eq new-type 1) 2)
                      ((eq new-type 2) 1)
                      ((not (or (eq type 1) (eq type 2)))
                       (error "Invalid title type"))
                      ((eq new-type nil) type)
                      ((eq new-type t) (if (eq type 1) 2 1))
                      (t (error "NEW-TYPE has invalid value"))))
           (sub-type (nth 1 descriptor))
           (new-sub-type-val (cond
                          ((eq new-sub-type 1) 2)
                          ((eq new-sub-type 2) 1)
                          ((null sub-type) adoc-default-title-sub-type) ; there wasn't a sub-type before
                          ((not (or (eq sub-type 1) (eq sub-type 2)))
                           (error "Invalid title sub-type"))
                          ((eq new-sub-type nil) sub-type)
                          ((eq new-sub-type t) (if (eq sub-type 1) 2 1))
                          (t (error "NEW-SUB-TYPE has invalid value"))))           
           (level (nth 2 descriptor))
           (new-level (cond
                      ((or (null new-level-rel) (eq new-level-rel 0))
                       level)
                      ((not (null new-level-rel))
                       (let ((x (% (+ level arg) (+ adoc-title-max-level 1))))
                         (if (< x 0)
                             (+ x adoc-title-max-level 1)
                           x)))
                      ((not (null new-level-abs))
                       new-level-abs)
                      (t
                       level)))
           (start (nth 4 descriptor))
           (end (nth 5 descriptor))
           (saved-col (current-column)))
      (setcar (nthcdr 0 descriptor) new-type-val)
      (setcar (nthcdr 1 descriptor) new-sub-type-val)
      (setcar (nthcdr 2 descriptor) new-level)
      (beginning-of-line)
      (delete-region start end)
      (insert (adoc-make-title descriptor))
      (when (eq new-type-val 2)
        (forward-line -1))
      (move-to-column saved-col))))

(defun adoc-promote-title (&optional arg)
  "Promotes the title point is on ARG levels.

When ARG is nil (i.e. when no prefix arg is given), it defaults
to 1. When ARG is negative, level is denoted that many levels. If
ARG is 0, see `adoc-adjust-title-del'."
  (interactive "p")
  (adoc-modify-title arg))

(defun adoc-denote-title (&optional arg)
  "Completely analgous to `adoc-promote-title'."
  (interactive "p")
  (adoc-promote-title (- arg)))

;; (defun adoc-set-title-level (&optional arg)
;;   ""
;;   (interactive "P")
;;   (cond
;;    ()
;;       (adoc-modify-title nil arg)
;;     (adoc-modify-title 1)))

(defun adoc-adjust-title-del ()
  "Adjusts delimiter to match the length of the title's text.

E.g. after editing a two line title, call `adoc-adjust-title-del' so
the underline has the correct length."
  (interactive)
  (adoc-modify-title))

(defun adoc-toggle-title-type (&optional type-type)
  "Toggles title's type.

If TYPE-TYPE is nil, title's type is toggled. If TYPE-TYPE is
non-nil, the sub type is toggled."
  (interactive "P") 
  (when type-type
    (setq type-type t))
  (adoc-modify-title nil nil (not type-type) type-type))

(defun adoc-make-unichar-alist()
  "Creates `adoc-unichar-alist' from `unicode-character-list'"
  (unless (boundp 'unicode-character-list)
    (load-library "unichars.el"))
  (let ((i unicode-character-list))
    (setq adoc-unichar-alist nil)
    (while i
      (let ((name (nth 2 (car i)))
            (codepoint (nth 0 (car i))))
        (when name
          (push (cons name codepoint) adoc-unichar-alist))
        (setq i (cdr i))))))

(defun adoc-unichar-by-name (name)
  "Returns unicode codepoint of char with the given NAME"
  (cdr (assoc name adoc-unichar-alist)))

(defun adoc-entity-to-string (entity)
  "Returns a string containing the character referenced by ENTITY.

ENTITY is a string containing a character entity reference like
e.g. '&#38;' or '&amp;'. nil is returned if its an invalid
entity, or when customizations prevent `adoc-entity-to-string' from
knowing it. E.g. when `adoc-unichar-name-resolver' is nil."
  (save-match-data
    (let (ch)
      (setq ch
        (cond
         ;; hex
         ((string-match "&#x\\([0-9a-fA-F]+?\\);" entity)
          (string-to-number (match-string 1 entity) 16))
         ;; dec
         ((string-match "&#\\([0-9]+?\\);" entity)
          (string-to-number (match-string 1 entity)))
         ;; name
         ((and adoc-unichar-name-resolver
               (string-match "&\\(.+?\\);" entity))
          (funcall adoc-unichar-name-resolver
                   (match-string 1 entity)))))
      (when (characterp ch) (make-string 1 ch)))))

(defun adoc-calc ()
  "(Re-)calculates variables used in adoc-mode.
Needs to be called after changes to certain (customization)
variables. Mostly in order font lock highlighting works as the
new customization demands."
  (interactive)

  (when (and (null adoc-insert-replacement)
             adoc-unichar-name-resolver)
    (message "Warning: adoc-unichar-name-resolver is non-nil, but is adoc-insert-replacement is nil"))
  (when (and (eq adoc-unichar-name-resolver 'adoc-unichar-by-name)
             (null adoc-unichar-alist))
    (adoc-make-unichar-alist))

  (setq adoc-font-lock-keywords (adoc-get-font-lock-keywords))
  (when (and font-lock-mode (eq major-mode 'adoc-mode))
    (font-lock-fontify-buffer)))

(adoc-calc)

;;;###autoload
(define-derived-mode adoc-mode text-mode "adoc"
  "Major mode for editing AsciiDoc text files.
Turning on Adoc mode runs the normal hook `adoc-mode-hook'."
  
  ;; syntax table
  ;; todo: do it as other modes do it, eg rst-mode?
  (modify-syntax-entry ?$ ".")
  (modify-syntax-entry ?% ".")
  (modify-syntax-entry ?& ".")
  (modify-syntax-entry ?' ".")
  (modify-syntax-entry ?` ".")
  (modify-syntax-entry ?\" ".")
  (modify-syntax-entry ?* ".")
  (modify-syntax-entry ?+ ".")
  (modify-syntax-entry ?. ".")
  (modify-syntax-entry ?/ ".")
  (modify-syntax-entry ?< ".")
  (modify-syntax-entry ?= ".")
  (modify-syntax-entry ?> ".")
  (modify-syntax-entry ?\\ ".")
  (modify-syntax-entry ?| ".")
  (modify-syntax-entry ?_ ".")

  ;; comments
  (set (make-local-variable 'comment-column) 0)
  (set (make-local-variable 'comment-start) "// ")
  (set (make-local-variable 'comment-end) "")
  (set (make-local-variable 'comment-start-skip) "^//[ \t]*")
  (set (make-local-variable 'comment-end-skip) "[ \t]*\n")
  
  ;; paragraphs
  (set (make-local-variable 'paragraph-separate) (adoc-re-paragraph-separate))
  (set (make-local-variable 'paragraph-start) (adoc-re-paragraph-start))
  (set (make-local-variable 'paragraph-ignore-fill-prefix) t)
  
  ;; font lock
  (set (make-local-variable 'font-lock-defaults)
       '(adoc-font-lock-keywords
	 nil nil nil nil
	 (font-lock-multiline . t)
	 (font-lock-mark-block-function . adoc-font-lock-mark-block-function)))
  (make-local-variable 'font-lock-extra-managed-props)
  (setq font-lock-extra-managed-props '(adoc-reserved))
  (make-local-variable 'font-lock-unfontify-region-function)
  (setq font-lock-unfontify-region-function 'adoc-unfontify-region-function)
  
  ;; outline mode
  ;; BUG: if there are many spaces\tabs after =, level becomes wrong
  ;; Ideas make it work for two line titles: Investigate into
  ;; outline-heading-end-regexp. It seams like outline-regexp could also contain
  ;; newlines.
  (set (make-local-variable 'outline-regexp) "=\\{1,5\\}[ \t]+[^ \t\n]")
  
  ;; misc
  (set (make-local-variable 'page-delimiter) "^<<<+$")
  (set (make-local-variable 'require-final-newline) t)
  (set (make-local-variable 'parse-sexp-lookup-properties) t)
  
  ;; compilation
  (when (boundp 'compilation-error-regexp-alist-alist)
    (add-to-list 'compilation-error-regexp-alist-alist
        '(asciidoc
          "^asciidoc: +\\(?:ERROR\\|\\(WARNING\\|DEPRECATED\\)\\): +\\([^:\n]*\\): line +\\([0-9]+\\)"
          2 3 nil (1 . nil))))
  (when (boundp 'compilation-error-regexp-alist)
    (make-local-variable 'compilation-error-regexp-alist)
    (add-to-list 'compilation-error-regexp-alist 'asciidoc))

  (run-hooks 'adoc-mode-hook))

(provide 'adoc-mode)

;;; adoc-mode.el ends here

