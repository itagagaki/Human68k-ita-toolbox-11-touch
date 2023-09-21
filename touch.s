* touch - change file date
*
* Itagaki Fumihiko 12-Oct-92  Create.
* 1.0
* Itagaki Fumihiko 06-Nov-92  strip_excessive_slashesのバグfixに伴う改版．
* 1.1
* Itagaki Fumihiko 16-Nov-92  get_present_timeの修正．
* 1.2
* Itagaki Fumihiko 30-Dec-92  tfopen を呼ばずに直接 OPEN するようにした．
* Itagaki Fumihiko 30-Dec-92  msg_write_disabled を perror に追加した．
* Itagaki Fumihiko 30-Dec-92  reffile のエラーは -f でも報告するようにした．
* Itagaki Fumihiko 30-Dec-92  reffile のメディアがプロテクトされているとエラーとなる不具合を修正．
* Itagaki Fumihiko 10-Jan-93  GETPDB -> lea $10(a0),a0
* Itagaki Fumihiko 20-Jan-93  引数 - と -- の扱いの変更
* Itagaki Fumihiko 22-Jan-93  スタックを拡張
* Itagaki Fumihiko 26-Jan-93  -f オプションが指定されている場合には，ファイル引数が与えられ
*                             ていなくても正常終了するようにした．
* 1.3
* Itagaki Fumihiko 03-Jan-94  -r <file> や -R <file> は -r<file> -R<file> と書いても良い．
* 1.4
* Itagaki Fumihiko 05-Jan-95  指定形式を [[CC]YY]MMDDhhmm[.ss] に変更
* 1.5
*
* Usage: touch [ -cdf ] [ -rR file | [[CC]YY]MMDDhhmm[.ss] ] [ -- ] <file> ...

.include doscall.h
.include error.h
.include stat.h
.include chrcode.h

.xref DecodeHUPAIR
.xref getlnenv
.xref isdigit
.xref issjis
.xref strlen
.xref strchr
.xref strfor1
.xref strip_excessive_slashes

STACKSIZE	equ	16384			*  スーパーバイザモードでは15KB以上必要

FLAG_c		equ	0
FLAG_d		equ	1
FLAG_f		equ	2
FLAG_r		equ	3
FLAG_R		equ	4

LNDRV_O_CREATE		equ	4*2
LNDRV_O_OPEN		equ	4*3
LNDRV_O_DELETE		equ	4*4
LNDRV_O_MKDIR		equ	4*5
LNDRV_O_RMDIR		equ	4*6
LNDRV_O_CHDIR		equ	4*7
LNDRV_O_CHMOD		equ	4*8
LNDRV_O_FILES		equ	4*9
LNDRV_O_RENAME		equ	4*10
LNDRV_O_NEWFILE		equ	4*11
LNDRV_O_FATCHK		equ	4*12
LNDRV_realpathcpy	equ	4*16
LNDRV_LINK_FILES	equ	4*17
LNDRV_OLD_LINK_FILES	equ	4*18
LNDRV_link_nest_max	equ	4*19
LNDRV_getrealpath	equ	4*20

.text
start:
		bra.s	start1
		dc.b	'#HUPAIR',0
start1:
		lea	stack_bottom(pc),a7		*  A7 := スタックの底
		lea	$10(a0),a0			*  A0 : PDBアドレス
		move.l	a7,d0
		sub.l	a0,d0
		move.l	d0,-(a7)
		move.l	a0,-(a7)
		DOS	_SETBLOCK
		addq.l	#8,a7
	*
	*  引数並び格納エリアを確保する
	*
		lea	1(a2),a0			*  A0 := コマンドラインの文字列の先頭アドレス
		bsr	strlen				*  D0.L := コマンドラインの文字列の長さ
		addq.l	#1,d0
		bsr	malloc
		bmi	insufficient_memory

		movea.l	d0,a1				*  A1 := 引数並び格納エリアの先頭アドレス
	*
	*  lndrv が組み込まれているかどうかを検査する
	*
		bsr	getlnenv
		move.l	d0,lndrv
	*
	*  オプション引数を解釈する
	*
		moveq	#0,d6				*  D6.W : エラー・コード
		bsr	DecodeHUPAIR			*  引数をデコードする
		movea.l	a1,a0				*  A0 : 引数ポインタ
		move.l	d0,d7				*  D7.L : 引数カウンタ
		moveq	#0,d5				*  D5.L : flags
		clr.l	a4				*  A4 : reffile
decode_opt_loop1:
		tst.l	d7
		beq	no_datime_arg

		move.b	(a0),d0
		bsr	isdigit
		beq	decode_datime_arg

		cmp.b	#'-',d0
		bne	no_datime_arg

		tst.b	1(a0)
		beq	no_datime_arg

		subq.l	#1,d7
		addq.l	#1,a0
		move.b	(a0)+,d0
		cmp.b	#'-',d0
		bne	decode_opt_loop2

		tst.b	(a0)+
		beq	no_datime_arg

		subq.l	#1,a0
decode_opt_loop2:
		moveq	#FLAG_c,d1
		cmp.b	#'c',d0
		beq	set_option

		moveq	#FLAG_d,d1
		cmp.b	#'d',d0
		beq	set_option

		moveq	#FLAG_f,d1
		cmp.b	#'f',d0
		beq	set_option

		moveq	#FLAG_r,d1
		cmp.b	#'r',d0
		beq	option_r

		moveq	#FLAG_R,d1
		cmp.b	#'R',d0
		beq	option_r

		moveq	#1,d1
		tst.b	(a0)
		beq	bad_option_1

		bsr	issjis
		bne	bad_option_1

		moveq	#2,d1
bad_option_1:
		move.l	d1,-(a7)
		pea	-1(a0)
		move.w	#2,-(a7)
		lea	msg_illegal_option(pc),a0
		bsr	werror_myname_and_msg
		DOS	_WRITE
		lea	10(a7),a7
		bra	usage

set_option:
		bset	d1,d5
set_option_done:
		move.b	(a0)+,d0
		bne	decode_opt_loop2
		bra	decode_opt_loop1

option_r:
		tst.b	(a0)
		bne	option_r_1

		subq.l	#1,d7
		bcs	too_few_args

		addq.l	#1,a0
option_r_1:
		bset	d1,d5
		movea.l	a0,a4
		bsr	strfor1
		bra	decode_opt_loop1

decode_datime_arg:
	*
	*  時刻指定引数を調べる
	*
		cmpa.l	#0,a4
		bne	bad_date

		subq.l	#1,d7
		moveq	#0,d1
		movea.l	a0,a1
		moveq	#'.',d0
		bsr	strchr
		exg	a0,a1
		move.l	a1,d0
		sub.l	a0,d0
		subq.l	#8,d0
		blo	bad_date
		beq	no_year

		subq.l	#2,d0
		blo	bad_date
		beq	year_2digit

		subq.l	#2,d0
		bne	bad_date
	*  CCYY
		bsr	get2digit
		mulu	#100,d0
		move.w	d0,d2
		bsr	get2digit
		add.w	d2,d0
		sub.w	#1980,d0
		blo	bad_year

		cmp.w	#127,d0
		bls	set_year
bad_year:
		lea	msg_bad_year(pc),a0
		bsr	werror_myname_and_msg
		bra	exit_1

year_2digit:
	*  YY
		bsr	get2digit
		sub.b	#80,d0
		bhs	set_year

		add.b	#100,d0
set_year:
		lsl.w	#4,d0
		lsl.w	#5,d0
		bra	set_year_1

no_year:
		DOS	_GETDATE
		and.w	#$fe00,d0
set_year_1:
		or.w	d0,d1
year_ok:
	*  MM
		bsr	get2digit
		beq	bad_date

		cmp.b	#12,d0
		bhi	bad_date

		lsl.w	#5,d0
		or.w	d0,d1
	*  DD
		bsr	get2digit
		beq	bad_date

		cmp.b	#31,d0
		bhi	bad_date

		or.w	d0,d1
		swap	d1
	*  hh
		bsr	get2digit
		cmp.b	#23,d0
		bhi	bad_date

		lsl.w	#6,d0
		lsl.w	#5,d0
		or.w	d0,d1
	*  mm
		bsr	get2digit
		cmp.b	#59,d0
		bhi	bad_date

		lsl.w	#5,d0
		or.w	d0,d1

	*  .ss
		move.b	(a0)+,d0
		beq	datimearg_ok

		cmp.b	#'.',d0
		bne	bad_date

		bsr	get2digit
		cmp.b	#59,d0
		bhi	bad_date

		lsr.w	#1,d0
		or.w	d0,d1

		tst.b	(a0)+
		bne	bad_date
datimearg_ok:
		tst.l	d7
		beq	touch_start

		cmpi.b	#'-',(a0)
		bne	touch_start

		cmpi.b	#'-',1(a0)
		bne	touch_start

		tst.b	2(a0)
		bne	touch_start

		addq.l	#3,a0
		subq.l	#1,d7
		bra	touch_start

no_datime_arg:
	*
	*  -rR が指定されているなら、そのファイルの時刻を、
	*  さもなくば現在時刻を得る
	*
		cmpa.l	#0,a4
		bne	get_reffile_datime

		bsr	get_present_time
		bra	touch_start

get_reffile_datime:
		exg	a0,a4
		btst	#FLAG_R,d5
		sne	d1
		move.l	d5,-(a7)
		bclr	#FLAG_f,d5
		bsr	findfile
		move.l	(a7)+,d5
		tst.l	d0
		bmi	exit_program

		tst.l	d2
		bmi	reffile_nofile

		btst	#MODEBIT_LNK,d2
		beq	do_get_reffile_datime

		*  シンボリック・リンク・ファイルの時刻を得る
		move.l	lndrv,d0
		beq	do_get_reffile_datime

		movea.l	d0,a2
		lea	refname(pc),a1
		clr.l	-(a7)
		DOS	_SUPER				*  スーパーバイザ・モードに切り換える
		addq.l	#4,a7
		move.l	d0,-(a7)			*  前の SSP の値
		movem.l	d5-d7/a0-a4,-(a7)
		move.l	a0,-(a7)
		move.l	a1,-(a7)
		movea.l	LNDRV_realpathcpy(a2),a3
		jsr	(a3)
		addq.l	#8,a7
		movem.l	(a7)+,d5-d7/a0-a4
		tst.l	d0
		bmi	reffile_bad_link

		movem.l	d5-d7/a0-a4,-(a7)
		move.w	#MODEVAL_ALL,-(a7)
		move.l	a1,-(a7)
		pea	filesbuf(pc)
		movea.l	a7,a6
		movea.l	LNDRV_O_FILES(a2),a3
		jsr	(a3)
		lea	10(a7),a7
		movem.l	(a7)+,d5-d7/a0-a4
		move.l	d0,d1
		DOS	_SUPER				*  ユーザ・モードに戻す
		addq.l	#4,a7
		move.l	d1,d0
		bra	do_get_reffile_datime_1

do_get_reffile_datime:
		move.w	#MODEVAL_ALL,-(a7)
		move.l	a1,-(a7)
		pea	filesbuf(pc)
		DOS	_FILES
		lea	10(a7),a7
do_get_reffile_datime_1:
		tst.l	d0
		bmi	reffile_perror

		move.l	filesbuf+ST_TIME(pc),d1
		swap	d1				*  D1.L : filedate
		exg	a0,a4
touch_start:
		move.l	d1,date
		tst.l	d7
		beq	no_filearg
touch_loop:
		movea.l	a0,a1
		bsr	strfor1
		move.l	a0,-(a7)
		movea.l	a1,a0
		bsr	strip_excessive_slashes
		bsr	touch_one
		movea.l	(a7)+,a0
		subq.l	#1,d7
		bne	touch_loop
exit_program:
		move.w	d6,-(a7)
		DOS	_EXIT2

bad_date:
		lea	msg_bad_date(pc),a0
		bra	werror_usage

no_filearg:
		btst	#FLAG_f,d5
		bne	exit_program
too_few_args:
		lea	msg_too_few_args(pc),a0
werror_usage:
		bsr	werror_myname_and_msg
usage:
		lea	msg_usage(pc),a0
		bsr	werror
exit_1:
		moveq	#1,d6
		bra	exit_program

reffile_perror:
		cmp.l	#ENODIR,d0
		bne	reffile_perror_1
reffile_nofile:
		moveq	#ENOFILE,d0
reffile_perror_1:
		bclr	#FLAG_f,d5
		bsr	perror
		bra	exit_program

reffile_bad_link:
		DOS	_SUPER				*  ユーザ・モードに戻す
		addq.l	#4,a7
		lea	msg_bad_link(pc),a2
		bsr	werror_myname_word_colon_msg
		bra	exit_program

insufficient_memory:
		lea	msg_no_memory(pc),a0
touch_error_exit_3:
		bsr	werror_myname_and_msg
		moveq	#3,d6
		bra	exit_program
*****************************************************************
* touch_one
*
* CALL
*      A0     filename
*
* RETURN
*      D0-D2/A0-A3   破壊
*****************************************************************
touch_one:
		btst	#FLAG_d,d5
		sne	d1
		bsr	findfile
		bmi	touch_return

		tst.l	d2
		bmi	touch_nofile

		moveq	#MODEVAL_ARC,d0
		btst	#FLAG_f,d5
		bne	touch_chmod

		move.b	d2,d0
		and.b	#(MODEVAL_VOL|MODEVAL_DIR|MODEVAL_LNK),d0
		beq	touch_mode_ok

		move.l	d2,d0
		bclr	#MODEBIT_VOL,d0
		bclr	#MODEBIT_DIR,d0
		bclr	#MODEBIT_LNK,d0
		bset	#MODEBIT_ARC,d0
touch_chmod:
		bsr	lchmod_a1
		bpl	touch_open
touch_mode_ok:
		moveq	#-1,d2
touch_open:
		moveq	#2,d0
		bsr	fopen_a1
		bra	do_touch_datime

touch_nofile:
		move.l	d2,d0
		cmp.l	#ENOFILE,d0
		bne	perror

		btst	#FLAG_c,d5
		bne	touch_return

		move.w	#MODEVAL_ARC,-(a7)
		move.l	a1,-(a7)
		DOS	_CREATE
		addq.l	#6,a7
		moveq	#-1,d2
do_touch_datime:
		move.l	d0,d1
		bmi	touch_open_fail

		move.l	date,-(a7)
		move.w	d1,-(a7)
		DOS	_FILEDATE
		addq.l	#6,a7
touch_done:
		bsr	fclose_d1
		bpl	touch_success
touch_open_fail:
		bsr	perror
touch_success:
		move.l	d2,d0
		bmi	touch_return

		bsr	lchmod_a1
		bpl	touch_return

		lea	msg_cannot_resume_mode(pc),a2
		bsr	werror_myname_word_colon_msg
touch_return:
		rts
*****************************************************************
get_present_time:
		movem.l	d0/d2,-(a7)
		DOS	_GETDATE
get_present_time_loop:
		move.w	d0,d2
		move.w	d0,d1
		swap	d1
		DOS	_GETTIME
		move.w	d0,d1
		DOS	_GETDATE
		cmp.w	d2,d0
		bne	get_present_time_loop

		movem.l	(a7)+,d0/d2
		rts
*****************************************************************
get2digit:
		move.w	d1,-(a7)
		moveq	#0,d0
		move.b	(a0)+,d0
		sub.b	#'0',d0
		blo	bad_date

		cmp.b	#9,d0
		bhi	bad_date

		mulu	#10,d0
		move.b	(a0)+,d1
		sub.b	#'0',d1
		blo	bad_date

		cmp.b	#9,d1
		bhi	bad_date

		add.b	d1,d0
		move.w	(a7)+,d1
		tst.l	d0
		rts
*****************************************************************
* findfile
*
* CALL
*      A0     filename
*      D1.B   0 : シンボリック・リンクを追う
*
* RETURN
*      A1     real pathname (points static)
*      D0.L   負ならエラー
*      D2.L   lgetmode_a1 のステータス
*      CCR    TST.L D0
*
* RETURN
*      D1/A2-A3   破壊
*****************************************************************
findfile:
		movea.l	a0,a1
		bsr	lgetmode_a1
		move.l	d0,d2				*  D2.L : mode
		bmi	findfile_nomode

		btst	#MODEBIT_LNK,d0
		beq	findfile_return

		tst.b	d1
		bne	findfile_return			*  リンク・ファイルそのものを得た

		*  リンクが参照するファイルを得る

		lea	msg_cannot_access_link(pc),a2
		move.l	lndrv,d0
		beq	findfile_werror

		movea.l	d0,a2
		movea.l	LNDRV_getrealpath(a2),a2
		lea	refname(pc),a1
		clr.l	-(a7)
		DOS	_SUPER				*  スーパーバイザ・モードに切り換える
		addq.l	#4,a7
		move.l	d0,-(a7)			*  前の SSP の値
		movem.l	d2-d7/a0-a1/a4-a6,-(a7)
		move.l	a0,-(a7)
		move.l	a1,-(a7)
		jsr	(a2)
		addq.l	#8,a7
		movem.l	(a7)+,d2-d7/a0-a1/a4-a6
		move.l	d0,d1
		DOS	_SUPER				*  ユーザ・モードに戻す
		addq.l	#4,a7
		lea	msg_bad_link(pc),a2
		tst.l	d1
		bmi	findfile_werror

		bsr	lgetmode_a1
		move.l	d0,d2
		bpl	findfile_return
findfile_nomode:
		lea	nameckbuf(pc),a3
		move.l	a3,-(a7)
		move.l	a1,-(a7)
		DOS	_NAMECK
		addq.l	#8,a7
		tst.l	d0
		bmi	findfile_perror

		tst.b	67(a3)				*  basename があるか？
		bne	findfile_return			*  D2.L < 0

		movea.l	a3,a1
		exg	a0,a1
		bsr	strip_excessive_slashes
		exg	a0,a1
		bsr	lgetmode_a1
		move.l	d0,d2
		bpl	findfile_return

		lea	msg_cannot_access_root(pc),a2
		tst.b	3(a1)
		beq	findfile_werror
findfile_return:
		moveq	#0,d0
		rts

findfile_perror:
		bsr	perror				*  NAMECK
findfile_error_return:
		moveq	#-1,d0
		rts

findfile_werror:
		bsr	werror_myname_word_colon_msg_f
		bra	findfile_error_return
*****************************************************************
lgetmode_a1:
		moveq	#-1,d0
lchmod_a1:
		move.w	d0,-(a7)
		move.l	a1,-(a7)
		DOS	_CHMOD
		addq.l	#6,a7
		tst.l	d0
		rts
*****************************************************************
fopen_a1:
		move.w	d0,-(a7)
		move.l	a1,-(a7)
		DOS	_OPEN
		addq.l	#6,a7
		tst.l	d0
		rts
*****************************************************************
fclose_d1:
		move.l	d0,-(a7)
		move.w	d1,-(a7)
		DOS	_CLOSE
		addq.l	#2,a7
		move.l	(a7)+,d0
		rts
*****************************************************************
malloc:
		move.l	d0,-(a7)
		DOS	_MALLOC
		addq.l	#4,a7
		tst.l	d0
		rts
*****************************************************************
werror_myname_and_msg:
		move.l	a0,-(a7)
		lea	msg_myname(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
werror:
		movem.l	d0/a1,-(a7)
		movea.l	a0,a1
werror_1:
		tst.b	(a1)+
		bne	werror_1

		subq.l	#1,a1
		suba.l	a0,a1
		move.l	a1,-(a7)
		move.l	a0,-(a7)
		move.w	#2,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		movem.l	(a7)+,d0/a1
		rts
*****************************************************************
werror_myname_word_colon_msg_f:
		btst	#FLAG_f,d5
		bne	werror_myname_word_colon_msg_return
werror_myname_word_colon_msg:
		bsr	werror_myname_and_msg
		move.l	a0,-(a7)
		lea	msg_colon(pc),a0
		bsr	werror
		movea.l	a2,a0
		bsr	werror
		lea	msg_newline(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
werror_myname_word_colon_msg_return:
		moveq	#2,d6
		rts
*****************************************************************
perror:
		movem.l	d0/a2,-(a7)
		not.l	d0		* -1 -> 0, -2 -> 1, ...
		cmp.l	#25,d0
		bls	perror_1

		moveq	#0,d0
perror_1:
		lea	perror_table(pc),a2
		lsl.l	#1,d0
		move.w	(a2,d0.l),d0
		lea	sys_errmsgs(pc),a2
		lea	(a2,d0.w),a2
		bsr	werror_myname_word_colon_msg_f
		movem.l	(a7)+,d0/a2
		rts
*****************************************************************
.data

	dc.b	0
	dc.b	'## touch 1.5 ##  Copyright(C)1992-95 by Itagaki Fumihiko',0

.even
perror_table:
	dc.w	msg_error-sys_errmsgs			*   0 ( -1)
	dc.w	msg_nofile-sys_errmsgs			*   1 ( -2)
	dc.w	msg_nopath-sys_errmsgs			*   2 ( -3)
	dc.w	msg_too_many_openfiles-sys_errmsgs	*   3 ( -4)
	dc.w	msg_error-sys_errmsgs			*   4 ( -5)
	dc.w	msg_error-sys_errmsgs			*   5 ( -6)
	dc.w	msg_error-sys_errmsgs			*   6 ( -7)
	dc.w	msg_error-sys_errmsgs			*   7 ( -8)
	dc.w	msg_error-sys_errmsgs			*   8 ( -9)
	dc.w	msg_error-sys_errmsgs			*   9 (-10)
	dc.w	msg_error-sys_errmsgs			*  10 (-11)
	dc.w	msg_error-sys_errmsgs			*  11 (-12)
	dc.w	msg_bad_name-sys_errmsgs		*  12 (-13)
	dc.w	msg_error-sys_errmsgs			*  13 (-14)
	dc.w	msg_bad_drive-sys_errmsgs		*  14 (-15)
	dc.w	msg_error-sys_errmsgs			*  15 (-16)
	dc.w	msg_error-sys_errmsgs			*  16 (-17)
	dc.w	msg_error-sys_errmsgs			*  17 (-18)
	dc.w	msg_write_disabled-sys_errmsgs		*  18 (-19)
	dc.w	msg_error-sys_errmsgs			*  19 (-20)
	dc.w	msg_error-sys_errmsgs			*  20 (-21)
	dc.w	msg_error-sys_errmsgs			*  21 (-22)
	dc.w	msg_disk_full-sys_errmsgs		*  22 (-23)
	dc.w	msg_directory_full-sys_errmsgs		*  23 (-24)
	dc.w	msg_error-sys_errmsgs			*  24 (-25)
	dc.w	msg_error-sys_errmsgs			*  25 (-26)

sys_errmsgs:
msg_error:		dc.b	'エラー',0
msg_nofile:		dc.b	'このようなファイルやディレクトリはありません',0
msg_nopath:		dc.b	'パスが存在していません',0
msg_too_many_openfiles:	dc.b	'オープンしているファイルが多すぎます',0
msg_bad_name:		dc.b	'名前が無効です',0
msg_bad_drive:		dc.b	'ドライブの指定が無効です',0
msg_write_disabled:	dc.b	'書き込みが許可されていません',0
msg_directory_full:	dc.b	'ディレクトリが満杯です',0
msg_disk_full:		dc.b	'ディスクが満杯です',0

msg_myname:			dc.b	'touch'
msg_colon:			dc.b	': ',0
msg_no_memory:			dc.b	'メモリが足りません',CR,LF,0
msg_illegal_option:		dc.b	'不正なオプション -- ',0
msg_bad_date:			dc.b	'日付と時刻の指定が正しくありません',0
msg_bad_year:			dc.b	'年は1980-2107の範囲に限られます',CR,LF,0
msg_too_few_args:		dc.b	'引数が足りません',0
msg_cannot_access_root:		dc.b	'ルート・ディレクトリにはアクセスできません',0
msg_cannot_access_link:		dc.b	'lndrvが組み込まれていないためシンボリック・リンク参照ファイルにアクセスできません',0
msg_bad_link:			dc.b	'異常なシンボリック・リンクです',0
msg_cannot_resume_mode:		dc.b	'PANIC! 属性を元に戻せませんでした',0
msg_usage:			dc.b	CR,LF
				dc.b	'使用法:  touch [-cdf] [ -rR <参照ファイル> | [[CC]YY]MMDDhhmm[.ss] ] [--] <ファイル> ...'
msg_newline:			dc.b	CR,LF,0
*****************************************************************
.bss

.even
lndrv:			ds.l	1
date:			ds.l	1
.even
filesbuf:		ds.b	STATBUFSIZE
refname:		ds.b	128
nameckbuf:		ds.b	91
mode_mask:		ds.b	1
mode_plus:		ds.b	1
.even
			ds.b	STACKSIZE
.even
stack_bottom:
*****************************************************************

.end start
