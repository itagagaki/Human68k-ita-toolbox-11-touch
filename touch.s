* touch - change file date
*
* Itagaki Fumihiko 12-Oct-92  Create.
*
* Usage: touch [ -cdf ] [ -rR file ] [ MMDDhhmm[[CC]YY][.ss] ] [ - ] <file> ...

.include doscall.h
.include error.h
.include stat.h
.include chrcode.h

.xref DecodeHUPAIR
.xref getlnenv
.xref isdigit
.xref issjis
.xref strlen
.xref strfor1
.xref strip_excessive_slashes
.xref tfopen
.xref fclose

STACKSIZE	equ	4096

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
		lea	stack_bottom,a7			*  A7 := スタックの底
		DOS	_GETPDB
		movea.l	d0,a0				*  A0 : PDBアドレス
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
		bsr	DecodeHUPAIR			*  引数をデコードする
		movea.l	a1,a0				*  A0 : 引数ポインタ
		move.l	d0,d7				*  D7.L : 引数カウンタ
		moveq	#0,d5				*  D5.L : flags
		clr.l	a4				*  A4 : reffile
		moveq	#0,d6				*  D6.W : エラー・コード
decode_opt_loop1:
		tst.l	d7
		beq	no_datime_arg

		move.b	(a0),d0
		bsr	isdigit
		beq	decode_datime_arg

		cmp.b	#'-',d0
		bne	no_datime_arg

		subq.l	#1,d7
		addq.l	#1,a0
		move.b	(a0)+,d0
		beq	no_datime_arg
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
		tst.b	(a0)+
		bne	bad_arg

		subq.l	#1,d7
		bcs	too_few_args

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
	*  MM
		bsr	get2digit
		bmi	bad_date
		beq	bad_date

		cmp.b	#12,d0
		bhi	bad_date

		lsl.w	#5,d0
		or.w	d0,d1
	*  DD
		bsr	get2digit
		bmi	bad_date
		beq	bad_date

		cmp.b	#31,d0
		bhi	bad_date

		or.w	d0,d1
		swap	d1
	*  hh
		bsr	get2digit
		bmi	bad_date

		cmp.b	#23,d0
		bhi	bad_date

		lsl.w	#6,d0
		lsl.w	#5,d0
		or.w	d0,d1
	*  mm
		bsr	get2digit
		bmi	bad_date

		cmp.b	#59,d0
		bhi	bad_date

		lsl.w	#5,d0
		or.w	d0,d1
	*  [[CC]YY]
		move.b	(a0),d0
		bsr	isdigit
		bne	year_default

		bsr	get2digit
		bmi	bad_date

		move.w	d0,d2
		move.b	(a0),d0
		bsr	isdigit
		bne	year_2digit

		bsr	get2digit
		bmi	bad_date

		mulu	#100,d2
		add.w	d0,d2
		sub.w	#1980,d2
		blo	bad_year

		cmp.w	#127,d2
		bls	set_year
bad_year:
		lea	msg_bad_year(pc),a0
		bsr	werror_myname_and_msg
		bra	exit_1

year_2digit:
		sub.b	#80,d2
		bhs	set_year

		add.b	#100,d2
set_year:
		lsl.w	#4,d2
		lsl.w	#5,d2
		swap	d1
		or.w	d2,d1
		swap	d1
		bra	year_ok

year_default:
		DOS	_GETDATE
		and.l	#$0000fe00,d0
		swap	d0
		or.l	d0,d1
year_ok:
	*  [.ss]
		move.b	(a0)+,d0
		beq	datimearg_ok

		cmp.b	#'.',d0
		bne	bad_date

		bsr	get2digit
		bmi	bad_date

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

		tst.b	1(a0)
		bne	touch_start

		addq.l	#2,a0
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
		bsr	findfile
		bmi	exit_program

		move.l	d2,d0
		bmi	reffile_perror

		exg	a0,a4
		moveq	#MODEVAL_ARC,d0
		bsr	lchmod
		moveq	#0,d0
		exg	a0,a1
		bsr	tfopen
		exg	a0,a1
		bmi	reffile_error2

		move.w	d0,d1
		clr.l	-(a7)
		move.w	d1,-(a7)
		DOS	_FILEDATE
		addq.l	#6,a7
		cmp.l	#$ffff0000,d0
		bhs	reffile_error3

		exg	d0,d1				*  D1.L : filedate
		bsr	fclose
		move.l	d2,d0
		bsr	lchmod
		bmi	reffile_error4
touch_start:
		move.l	d1,date
		tst.l	d7
		beq	too_few_args
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
		bra	bad_arg_1

too_few_args:
		lea	msg_too_few_args(pc),a0
		bra	bad_arg_1

bad_arg:
		lea	msg_bad_arg(pc),a0
bad_arg_1:
		bsr	werror_myname_and_msg
usage:
		lea	msg_usage(pc),a0
		bsr	werror
exit_1:
		moveq	#1,d6
		bra	exit_program

reffile_error3:
		bsr	fclose1
reffile_error2:
		bsr	perror
		move.l	d2,d0
		bsr	lchmod
		bsr	lgetmode
		cmp.l	d2,d0
		beq	exit_program
reffile_error4:
		exg	a0,a1
		bsr	cannot_resume_mode
		exg	a0,a1
		bra	exit_program

reffile_perror:
		cmp.l	#ENODIR,d0
		bne	reffile_perror_1

		moveq	#ENOFILE,d0
reffile_perror_1:
		bsr	perror
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
		bne	touch_force

		move.b	d2,d0
		and.b	#(MODEVAL_VOL|MODEVAL_DIR|MODEVAL_LNK),d0
		beq	touch_mode_ok

		move.l	d2,d0
		bclr	#MODEBIT_VOL,d0
		bclr	#MODEBIT_DIR,d0
		bclr	#MODEBIT_LNK,d0
		bset	#MODEBIT_ARC,d0
touch_force:
		bsr	lchmod
		bpl	touch_open
touch_mode_ok:
		moveq	#-1,d2
touch_open:
		moveq	#2,d0
		exg	a0,a1
		bsr	tfopen
		exg	a0,a1
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
		bsr	fclose1
		bpl	touch_success
touch_open_fail:
		bsr	perror
touch_success:
		move.l	d2,d0
		bmi	touch_return

		bsr	lchmod
		bmi	cannot_resume_mode
touch_return:
		rts

cannot_resume_mode:
		lea	msg_cannot_resume_mode(pc),a2
		bra	werror_myname_word_colon_msg
*****************************************************************
get_present_time:
		movem.l	d0/a2,-(a7)
		DOS	_GETDATE
		move.l	d0,d2
		move.w	d0,d1
		swap	d1
get_present_time_loop:
		DOS	_GETTIME
		move.w	d0,d1
		DOS	_GETDATE
		cmp.l	d2,d0
		beq	get_present_time_return

		move.l	d0,d2
		bra	get_present_time_loop

get_present_time_return:
		movem.l	(a7)+,d0/d2
		rts
*****************************************************************
get2digit:
		move.w	d1,-(a7)
		moveq	#0,d0
		move.b	(a0)+,d0
		sub.b	#'0',d0
		blo	get2digit_error

		cmp.b	#9,d0
		bhi	get2digit_error

		mulu	#10,d0
		move.b	(a0)+,d1
		sub.b	#'0',d1
		blo	get2digit_error

		cmp.b	#9,d1
		bhi	get2digit_error

		add.b	d1,d0
get2digit_return:
		move.w	(a7)+,d1
		tst.l	d0
		rts

get2digit_error:
		moveq	#-1,d0
		bra	get2digit_return
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
*      D2.L   lgetmode のステータス
*      CCR    TST.L D0
*
* RETURN
*      D1/A2-A3   破壊
*****************************************************************
findfile:
		movea.l	a0,a1
		bsr	lgetmode
		move.l	d0,d2				*  D2.L : mode
		bmi	findfile_nomode

		btst	#MODEBIT_LNK,d0
		beq	findfile_return

		tst.b	d1
		bne	findfile_return

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

		bsr	lgetmode
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
		bsr	lgetmode
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
lgetmode:
		moveq	#-1,d0
lchmod:
		move.w	d0,-(a7)
		move.l	a1,-(a7)
		DOS	_CHMOD
		addq.l	#6,a7
		tst.l	d0
		rts
*****************************************************************
fclose1:
		move.l	d0,-(a7)
		move.w	d1,d0
		bsr	fclose
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
werror_word_msg_and_set_error:
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
	dc.b	'## touch 1.0 ##  Copyright(C)1992 by Itagaki Fumihiko',0

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
	dc.w	msg_error-sys_errmsgs			*  18 (-19)
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
msg_directory_full:	dc.b	'ディレクトリが満杯です',0
msg_disk_full:		dc.b	'ディスクが満杯です',0

msg_myname:			dc.b	'touch'
msg_colon:			dc.b	': ',0
msg_no_memory:			dc.b	'メモリが足りません',CR,LF,0
msg_illegal_option:		dc.b	'不正なオプション -- ',0
msg_bad_arg:			dc.b	'引数が正しくありません',0
msg_bad_date:			dc.b	'日付と時刻の指定が正しくありません',0
msg_bad_year:			dc.b	'年は1980-2107の範囲に限られます',CR,LF,0
msg_too_few_args:		dc.b	'引数が足りません',0
msg_cannot_access_root:		dc.b	'ルート・ディレクトリにはアクセスできません',0
msg_cannot_access_link:		dc.b	'lndrvが組み込まれていないためシンボリック・リンク参照ファイルにアクセスできません',0
msg_bad_link:			dc.b	'異常なシンボリック・リンクです',0
msg_cannot_resume_mode:		dc.b	'PANIC! 属性を元に戻せませんでした',0
msg_usage:			dc.b	CR,LF
				dc.b	'使用法:  touch [-cdf] [-rR <参照ファイル>] [MMDDhhmm[[CC]YY][.ss]] [-] <ファイル> ...'
msg_newline:			dc.b	CR,LF,0
*****************************************************************
.bss

.even
lndrv:			ds.l	1
date:			ds.l	1
refname:		ds.b	128
nameckbuf:		ds.b	91
mode_mask:		ds.b	1
mode_plus:		ds.b	1
buffer:			ds.b	1
.even
			ds.b	STACKSIZE
.even
stack_bottom:
*****************************************************************

.end start
