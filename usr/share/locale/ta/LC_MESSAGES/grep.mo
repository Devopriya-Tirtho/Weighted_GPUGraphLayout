��    e      D  �   l      �  �   �  �   a	  �  Y
    /  �   @  �  =  U  �  �  J  �    F  �     �       &        E  !   b     �     �     �  ,   �     �  .     '   M  (   u     �  %   �     �     �     �  *   �  �   &  &   �     �     �          .  $   F     k     }  �   �     C     T     ]     |     �  <   �  #   �               4  "   H     k     s  &   �     �     �     �     �       )        <  �   Q     K  ;   b  3   �  /   �  +     '   .  #   V     z     �     �     �     �  4   �       !   9  -   [  .   �     �     �     �                 ?      R      d      u      �      �      �   ,   �   *   �      !     &!     3!     @!     T!     n!  -   �!     �!  �  �!  h  A#  �  �$  �  �&  *  h*    �.    �0  �  �3  �  ^7  �  ;    �>  %   �@  P   A  �   hA  `   �A  N   KB  %   �B  J   �B  8   C  \   DC  L   �C  r   �C  h   aD  f   �D  O   1E  k   �E     �E     �E  $   �E  �   F  u  �F  a   OH  @   �H  ]   �H  A   PI  \   �I  _   �I  T   OJ  I   �J  �  �J  4   �L  +   �L  i   M     �M  $   �M  �   �M  L   XN  b   �N  W   O  �   `O  x   ]P     �P  4   �P  t   Q  P   �Q  0   �Q  0   R  <   FR     �R  �   �R  A   'S  <  iS  9   �V  f   �V  U   GW  R   �W  M   �W  I   >X  E   �X  B   �X  =   Y      OY     pY  Q   tY  �   �Y  8   NZ  o   �Z  l   �Z  �   d[  %   �[  T   \  G   h\  b   �\  A   ]  A   U]  J   �]  4   �]  X   ^     p^  b   �^  %   �^  �   _  M   �_     �_     `     0`  9   K`  J   �`  W   �`  `   (a     �a     a   ;   <   8          4   )      *      d   Y      D           Z   C       S   %   /       K   2   ,           \   >   H      R       W                  G                U          =   	          ]   [   M   I      6   ?   L   P       F   Q   $                     7                 J   0       N   9   #           3         !   `   .         E   T   b          :   A   5   (         
       @           V   "   ^   -   e         +      1   O                 '   c           _       &       B                   X    
Context control:
  -B, --before-context=NUM  print NUM lines of leading context
  -A, --after-context=NUM   print NUM lines of trailing context
  -C, --context=NUM         print NUM lines of output context
 
Miscellaneous:
  -s, --no-messages         suppress error messages
  -v, --invert-match        select non-matching lines
  -V, --version             display version information and exit
      --help                display this help text and exit
 
Output control:
  -m, --max-count=NUM       stop after NUM selected lines
  -b, --byte-offset         print the byte offset with output lines
  -n, --line-number         print line number with output lines
      --line-buffered       flush output on every line
  -H, --with-filename       print file name with output lines
  -h, --no-filename         suppress the file name prefix on output
      --label=LABEL         use LABEL as the standard input file name prefix
       --include=GLOB        search only files that match GLOB (a file pattern)
      --exclude=GLOB        skip files that match GLOB
      --exclude-from=FILE   skip files that match any file pattern from FILE
      --exclude-dir=GLOB    skip directories that match GLOB
   -E, --extended-regexp     PATTERNS are extended regular expressions
  -F, --fixed-strings       PATTERNS are strings
  -G, --basic-regexp        PATTERNS are basic regular expressions
  -P, --perl-regexp         PATTERNS are Perl regular expressions
   -I                        equivalent to --binary-files=without-match
  -d, --directories=ACTION  how to handle directories;
                            ACTION is 'read', 'recurse', or 'skip'
  -D, --devices=ACTION      how to handle devices, FIFOs and sockets;
                            ACTION is 'read' or 'skip'
  -r, --recursive           like --directories=recurse
  -R, --dereference-recursive  likewise, but follow all symlinks
   -L, --files-without-match  print only names of FILEs with no selected lines
  -l, --files-with-matches  print only names of FILEs with selected lines
  -c, --count               print only a count of selected lines per FILE
  -T, --initial-tab         make tabs line up (if needed)
  -Z, --null                print 0 byte after FILE name
   -NUM                      same as --context=NUM
      --group-separator=SEP  print SEP on line between matches with context
      --no-group-separator  do not print separator for matches with context
      --color[=WHEN],
      --colour[=WHEN]       use markers to highlight the matching strings;
                            WHEN is 'always', 'never', or 'auto'
  -U, --binary              do not strip CR characters at EOL (MSDOS/Windows)

   -e, --regexp=PATTERNS     use PATTERNS for matching
  -f, --file=FILE           take PATTERNS from FILE
  -i, --ignore-case         ignore case distinctions in patterns and data
      --no-ignore-case      do not ignore case distinctions (default)
  -w, --word-regexp         match only whole words
  -x, --line-regexp         match only whole lines
  -z, --null-data           a data line ends in 0 byte, not newline
   -o, --only-matching       show only nonempty parts of lines that match
  -q, --quiet, --silent     suppress all normal output
      --binary-files=TYPE   assume that binary files are TYPE;
                            TYPE is 'binary', 'text', or 'without-match'
  -a, --text                equivalent to --binary-files=text
 %s home page: <%s>
 %s: binary file matches %s: exceeded PCRE's backtracking limit %s: exhausted PCRE JIT stack %s: input file is also the output %s: internal PCRE error: %d %s: invalid option -- '%c'
 %s: memory exhausted %s: option '%s%s' doesn't allow an argument
 %s: option '%s%s' is ambiguous
 %s: option '%s%s' is ambiguous; possibilities: %s: option '%s%s' requires an argument
 %s: option requires an argument -- '%c'
 %s: unrecognized option '%s%s'
 %s: warning: recursive directory loop ' (C) (standard input) -P supports only unibyte and UTF-8 locales Example: %s -i 'hello world' menu.h main.c
PATTERNS can contain multiple patterns separated by newlines.

Pattern selection and interpretation:
 General help using GNU software: <%s>
 Invalid back reference Invalid character class name Invalid collation character Invalid content of \{\} Invalid preceding regular expression Invalid range end Invalid regular expression License GPLv3+: GNU GPL version 3 or later <%s>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
 Memory exhausted No match No previous regular expression Packaged by %s
 Packaged by %s (%s)
 Perl matching not supported in a --disable-perl-regexp build Premature end of regular expression Regular expression too big Report %s bugs to: %s
 Report bugs to: %s
 Search for PATTERNS in each FILE.
 Success Trailing backslash Try '%s --help' for more information.
 Unknown system error Unmatched ( or \( Unmatched ) or \) Unmatched [, [^, [:, [., or [= Unmatched \{ Usage: %s [OPTION]... PATTERNS [FILE]...
 Valid arguments are: When FILE is '-', read standard input.  With no FILE, read '.' if
recursive, '-' otherwise.  With fewer than two FILEs, assume -h.
Exit status is 0 if any line is selected, 1 otherwise;
if any error occurs and -q is not given, the exit status is 2.
 Written by %s and %s.
 Written by %s, %s, %s,
%s, %s, %s, %s,
%s, %s, and others.
 Written by %s, %s, %s,
%s, %s, %s, %s,
%s, and %s.
 Written by %s, %s, %s,
%s, %s, %s, %s,
and %s.
 Written by %s, %s, %s,
%s, %s, %s, and %s.
 Written by %s, %s, %s,
%s, %s, and %s.
 Written by %s, %s, %s,
%s, and %s.
 Written by %s, %s, %s,
and %s.
 Written by %s, %s, and %s.
 Written by %s.
 ` ambiguous argument %s for %s character class syntax is [[:space:]], not [:space:] conflicting matchers specified exceeded PCRE's line length limit failed to return to initial working directory failed to set file descriptor text/binary mode input is too large to count invalid argument %s for %s invalid character class invalid content of \{\} invalid context length argument invalid matcher %s invalid max count memory exhausted no syntax specified program error regular expression too big stack overflow the -P option only supports a single pattern unable to record current working directory unbalanced ( unbalanced ) unbalanced [ unfinished \ escape unknown binary-files type unknown devices method warning: --unix-byte-offsets (-u) is obsolete write error Project-Id-Version: GNU grep 3.6.27
Report-Msgid-Bugs-To: bug-grep@gnu.org
PO-Revision-Date: 2021-08-28 03:18+0530
Last-Translator: Arun Isaac <arunisaac@systemreboot.net>
Language-Team: Tamil <tamil@systemreboot.net>
Language: ta
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 8bit
X-Bugs: Report translation errors to the Language-Team address.
 
சூழல்:
  -B, --before-context=<எண்>  முந்தைய <எண்> வரிகளைக் காட்டு
  -A, --after-context=<எண்>   பிந்தைய <எண்> வரிகளைக் காட்டு
  -C, --context=<எண்>         சூழ்ந்த <எண்> வரிகளைக் காட்டு
 
பிற:
  -s, --no-messages         பிழைச் செய்திகளைக் காட்டாதே
  -v, --invert-match        பொருந்தா வரிகளைத் தேர்ந்தெடு
  -V, --version             பதிப்பு விவரத்தைக் காட்டி வெளியேறு
      --help                இவ்வுதவி உரையைக் காட்டி வெளியேறு
 
வெளியீடு:
  -m, --max-count=<எண்>     <எண்> வரிகளை மட்டும் காட்டு
  -b, --byte-offset          வரிகளுடன் எண்ணிருமி இருப்புநிலையைக் காட்டு
  -n, --line-number          வரிகளுடன் வரி எண்ணையும் காட்டு
      --line-buffered        ஒவ்வொரு வரிக்குப் பின்னும் வெளியீட்டைத் தள்ளு
  -H, --with-filename        வரிகளுடன் கோப்புப் பெயரையும் காட்டு
  -h, --no-filename          வெளியீட்டுக்கு முன் கோப்புப் பெயரைக் காட்டாதே
      --label=<பெயர்>        <பெயரை> இயல் உள்ளீட்டின் பெயராக பயன்படுத்து
       --include=<கோப்புப்பெயர்ப் பாங்கு>       கோப்பின் பெயர் <கோப்புப்பெயர்ப் பாங்குடன்> பொருந்தின் மட்டுமே அதைத் தேடு
      --exclude=<கோப்புப்பெயர்ப் பாங்கு>       கோப்பின் பெயர் <கோப்புப்பெயர்ப் பாங்குடன்> பொருந்தின் அதைத் தேடாதே
      --exclude-from=<கோப்பு>                கோப்பின் பெயர் <கோப்பிலுள்ள> பாங்குகளுடன் பொருந்தின் அதைத் தேடாதே
      --exclude-dir=<கோப்புப்பெயர்ப் பாங்கு>   அடைவின் பெயர் <கோப்புப்பெயர்ப் பாங்குடன்> பொருந்தின் அதைத் தேடாதே
   -E, --extended-regexp      <தேடுதொடர்கள்> விரிவுபட்ட தேடுகுறித்தொடர்கள்
  -F, --fixed-strings        <தேடுதொடர்கள்> உருச்சரங்கள்
  -G, --basic-regexp         <தேடுதொடர்கள்> அடிப்படை தேடுகுறித்தொடர்கள்
  -P, --perl-regexp          <தேடுதொடர்கள்> Perl தேடுகுறித்தொடர்கள்
   -I                            --binary-files=without-match என்பதை ஒத்தது
  -d, --directories=<செயல்>    அடைவு கையாள் முறை;
                                <செயல்> 'read', 'recurse' அல்லது 'skip'
  -D, --devices=<செயல்>        கருவி, பெயருடை புழம்பு, பொருந்துவாய் கையாள் முறை;
                                <செயல்> 'read' அல்லது 'skip'
  -r, --recursive               --directories=recurse என்பதை ஒத்தது
  -R, --dereference-recursive   -r போன்று, ஆனால் மென்தொடுப்புகளைப் பின் தொடர்
   -L, --files-without-match  தேர்ந்தெடுக்கப்பட்ட வரிகள் இல்லாக் <கோப்புகளை> மட்டும் பட்டியலிடு
  -l, --files-with-matches   தேர்ந்தெடுக்கப்பட்ட வரிகள் உள்ள <கோப்புகளை> மட்டும பட்டியலிடு
  -c, --count                ஒவ்வொரு <கோப்பிலும்> தேர்ந்தெடுக்கப்பட்ட வரிகளின் எண்ணிக்கையை மட்டும் காட்டு
  -T, --initial-tab          தத்தல்களை ஒன்றின் கீழ் ஒன்றமை (தேவைப்படின்)
  -Z, --null                 <கோப்புப்> பெயர் பின் 0 எண்ணிருமியை இடு
   -<எண்>                         --context=<எண்> என்பதை ஒத்தது
       --group-separator=<பிரியி>  சூழலுடை பொருத்தங்களிடையே <பிரியியை> இடு
       --no-group-separator       சூழலுடை பொருத்தங்களைப் பிரிக்காதே
       --color[=எப்போது],
       --colour[=எப்போது]        பொருந்தும் தொடர்களை நிறங்களுடன் எடுப்பாய்க் காட்டு;
                                  <எப்போது> 'always', 'never' அல்லது 'auto' என இருக்கலாம்
  -U, --binary                    வரி ஈற்றிலுள்ள ஏந்தி மீளல் (CR) வரியுருக்களை அழிக்காதே (MSDOS/Windows)
   -e, --regexp=<தேடுதொடர்கள்>     <தேடுதொடர்களைக்> கொண்டு ஒப்பிடு
  -f, --file=<கோப்பு>              <தேடுதொடர்களைக்> <கோப்பிலிருந்து> எடு
  -i, --ignore-case                எழுத்துயர்நிலையைப் பொருட்படுத்தாதே
      --no-ignore-case             எழுத்துயர்நிலையைப் பொருட்படுத்து (கூறா நிலை)
  -w, --word-regexp                முழு சொற்களையே ஒப்பிடு
  -x, --line-regexp                முழு வரிகளையே ஒப்பிடு
  -z, --null-data                  வரி 0 எண்ணிருமியில் முடிகிறது, புதிய வரியுருவில் அல்ல
   -o, --only-matching        பொருந்திய பகுதிகளை மட்டும் காட்டு
  -q, --quiet, --silent      எதையும் வெளியிடாதே
      --binary-files=<வகை> இருமக்கோப்புகள் <வகையெனக்> கொள்;
                             <வகை> 'binary', 'text' அல்லது 'without-match' என இருக்கலாம்
  -a, --text                 --binary-files=text என்பதை ஒத்தது
 %s வலைத்தளம்: <%s>
 %s: இருமக்கோப்பு பொருந்துகிறது %s: PCRE நிரலகத்தின் பின்வாங்கல் வரம்பு மீறப்பட்டது %s: PCRE நிரலகத்தின் JIT அடுக்கு தீர்ந்தது %s: உள்ளீடும் வெளியீடும் ஒன்றே %s: PCRE அகப்பிழை: %d %s: ஏற்கத்தகா செயல்மாற்றி -- '%c'
 %s: நினைவகம் தீர்ந்தது %s: செயல்மாற்றி '%s%s' செயலுருபு அற்றது
 %s: செயல்மாற்றி '%s%s' தெளிவற்றது
 %s: செயல்மாற்றி '%s%s' தெளிவற்றது; ஏற்கத்தக்கவை: %s: '%s%s' செயல்மாற்றிக்குச் செயலுருபு தேவை
 %s: '%c' செயல்மாற்றிக்குச் செயலுருபு தேவை
 %s: அறியப்படாச் செயல்மாற்றி '%s%s'
 %s: எச்சரிக்கை: தற்சுருண்ட அடைவுச் சுற்று ” © (இயல் உள்ளீடு) -P ஒற்றை எண்ணிருமி வட்டாரங்களிலும் UTF-8 வட்டாரங்களிலும் மட்டுமே இயங்கும் எடுத்துக்காட்டு: %s -i 'hello world' menu.h main.c
<தேடுதொடர்கள்> புதிய வரி வரியுருக்களால் பிரிந்த பலத் தொடர்களைக் கொள்ளலாம்.

தேடுதொடர்கள் தேர்வும் பொருளும்:
 GNU மென்பொருள் பயன்பாட்டு உதவிக்கு: <%s>
 ஏற்கத்தகா முன்குறிப்பு ஏற்கத்தகா வரியுரு வகுப்புப் பெயர் ஏற்கத்தகா ஒப்பாய்வு உரு ஏற்கத்தகா நெளி அடைவு \{\} உள்ளடக்கம் ஏற்கத்தகா முந்தைய தேடுகுறித்தொடர் ஏற்கத்தகா வரியுரு வரிசை முடிவு ஏற்கத்தகா தேடுகுறித்தொடர் உரிமம் GPLv3+: GNU GPL பதிப்பு 3 அல்லது பிந்தைய பதிப்புகள் <%s>.
இதுக் கட்டற்ற மென்பொருள்; இதை மாற்றவோ பரிமாறவோ தடையில்லை.
சட்டத்தால் அனுமதிக்கப்பட்ட அளவிற்கு எந்த உத்தரவாதமும் இல்லை.
 நினைவகம் தீர்ந்தது பொருத்தம் இல்லை முந்தைய தேடுகுறித்தொடர் எதுவும் இல்லை தொகுத்தது %s
 தொகுத்தது %s (%s)
 --disable-perl-regexp கொண்டு பெயர்க்கப்பட்டதால் Perl ஒப்பீடு இல்லை நிறைவுறாத் தேடுகுறித்தொடர் தேடுகுறித்தொடர் அளவிற்கு மிஞ்சியது %s வழுக்களை %s முகவரியில் அறிவிக்க
 வழுக்களை %s முகவரியில் தெரிவிக்க.
தமிழாக்க வழுக்களை tamil@systemreboot.net மின்னஞ்சல் முகவரியில் தெரிவிக்க.
 ஒவ்வொருக் <கோப்பிலும்> <தேடுதொடர்களைத்> தேடு.
 வெற்றி தொங்கும் பின்கீறல் மேலும் விவரத்திற்கு '%s --help' கட்டளையை இயக்குக.
 அறியப்படாக் கணிப்பொறிப் பிழை நிறைவுறா ( அல்லது \( நிறைவுறா ) அல்லது \) நிறைவுறா [, [^, [:, [. அல்லது [= நிறைவுறா \{ பயன்பாடு: %s [<செயல்மாற்றி>]... <தேடுதொடர்கள்> [<கோப்பு>]...
 ஏற்கத்தகு செயலுருபுகள்: <கோப்பு> '-' எனின், இயல் உள்ளீடைப் படி.  <கோப்பு> இல்லின் மீள்சுருளாயின் '.'
கோப்பைப் படி; மீள்சுருள் இல்லின் இயல் உள்ளீட்டைப் படி.  ஒரேக் <கோப்பெனின்> -h எனக்
கொள்.  ஏதாவது வரி தேர்ந்தெடுக்கப்பட்டால் வெளியேற்ற நிலை 0, எவையும்
தேர்ந்தெடுக்கபடவில்லையெனின் வெளியேற்ற நிலை 1; -q கொடுக்கப்பட்டு பிழையுற்றின்
வெளியேற்ற நிலை 2.
 எழுதியவர் %s மற்றும் %s.
 எழுதியவர் %s, %s, %s,
%s, %s, %s, %s,
%s, %s மற்றும் பிறர்.
 எழுதியவர் %s, %s, %s,
%s, %s, %s, %s,
%s மற்றும் %s.
 எழுதியவர் %s, %s, %s,
%s, %s, %s, %s,
மற்றும் %s.
 எழுதியவர் %s, %s, %s,
%s, %s, %s மற்றும் %s.
 எழுதியவர் %s, %s, %s,
%s, %s மற்றும் %s.
 எழுதியவர் %s, %s, %s,
%s மற்றும் %s.
 எழுதியவர் %s, %s, %s,
மற்றும் %s.
 எழுதியவர் %s, %s மற்றும் %s.
 எழுதியவர் %s.
 “ %2$s க்குத் தெளிவற்ற செயலுருபு %1$s வரியுரு வகுப்பை [[:space:]] எனக் குறிப்பிடுக, [:space:] என்றல்ல முரணான தேடல் முறைகள் PCRE நிரலகத்தின் வரி நீள வரம்பு மீறப்பட்டது முதல் பணியடைவிற்குத் திரும்ப இயலவில்லை கோப்பு விவரிப்பிக்கு text/binary பாங்கை அளிக்க இயலவில்லை கூட்டல் வழிவு %2$s க்கு ஏற்கத்தகாச் செயலுருபு %1$s ஏற்கத்தகா வரியுரு வகுப்பு ஏற்கத்தகா நெளி அடைப்பு \{\} உள்ளடக்கம் ஏற்கத்தகாச் சூழல் நீளம் ஏற்கத்தகாத் தேடல் முறை %s ஏற்கத்தகா வரிகள் எண்ணிக்கை நினைவகம் தீர்ந்தது தொடரமைப்பு குறிப்பிடப்படவில்லை நிரல் பிழை தேடுகுறித்தொடர் அளவிற்கு மிஞ்சியது அடுக்கு வழிவு -P செயல்மாற்றிக்கு ஒருத் தேடுதொடர் தான் இருக்க வேண்டும் பணியடைவைப் பதிக்க இயலவில்லை நிறைவுறா ( நிறைவுறா ) நிறைவுறா [ நிறைவுறா \ விடுவிப்பு ஏற்கத்தகா இருமக்கோப்பு வகை அறியப்படாக் கருவிக் கையாள் முறை எச்சரிக்கை: --unix-byte-offsets (-u) வழக்கொழிந்தது எழுது பிழை 