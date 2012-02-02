/*
 * 01/24/2005
 *
 * HTMLTokenMaker.java - Generates tokens for HTML syntax highlighting.
 * Copyright (C) 2005 Robert Futrell
 * robert_futrell at users.sourceforge.net
 * http://fifesoft.com/rsyntaxtextarea
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA.
 */
package org.fife.ui.rsyntaxtextarea.modes;

import java.io.*;
import javax.swing.text.Segment;

import org.fife.ui.rsyntaxtextarea.*;


/**
 * Scanner for HTML 5 files.
 *
 * This implementation was created using
 * <a href="http://www.jflex.de/">JFlex</a> 1.4.1; however, the generated file
 * was modified for performance.  Memory allocation needs to be almost
 * completely removed to be competitive with the handwritten lexers (subclasses
 * of <code>AbstractTokenMaker</code>, so this class has been modified so that
 * Strings are never allocated (via yytext()), and the scanner never has to
 * worry about refilling its buffer (needlessly copying chars around).
 * We can achieve this because RText always scans exactly 1 line of tokens at a
 * time, and hands the scanner this line as an array of characters (a Segment
 * really).  Since tokens contain pointers to char arrays instead of Strings
 * holding their contents, there is no need for allocating new memory for
 * Strings.<p>
 *
 * The actual algorithm generated for scanning has, of course, not been
 * modified.<p>
 *
 * If you wish to regenerate this file yourself, keep in mind the following:
 * <ul>
 *   <li>The generated HTMLTokenMaker.java</code> file will contain two
 *       definitions of both <code>zzRefill</code> and <code>yyreset</code>.
 *       You should hand-delete the second of each definition (the ones
 *       generated by the lexer), as these generated methods modify the input
 *       buffer, which we'll never have to do.</li>
 *   <li>You should also change the declaration/definition of zzBuffer to NOT
 *       be initialized.  This is a needless memory allocation for us since we
 *       will be pointing the array somewhere else anyway.</li>
 *   <li>You should NOT call <code>yylex()</code> on the generated scanner
 *       directly; rather, you should use <code>getTokenList</code> as you would
 *       with any other <code>TokenMaker</code> instance.</li>
 * </ul>
 *
 * @author Robert Futrell
 * @version 0.8
 *
 */
%%

%public
%class HTMLTokenMaker
%extends AbstractMarkupTokenMaker
%unicode
%type org.fife.ui.rsyntaxtextarea.Token


%{

	/**
	 * Type specific to XMLTokenMaker denoting a line ending with an unclosed
	 * double-quote attribute.
	 */
	public static final int INTERNAL_ATTR_DOUBLE			= -1;


	/**
	 * Type specific to XMLTokenMaker denoting a line ending with an unclosed
	 * single-quote attribute.
	 */
	public static final int INTERNAL_ATTR_SINGLE			= -2;


	/**
	 * Token type specific to HTMLTokenMaker; this signals that the user has
	 * ended a line with an unclosed HTML tag; thus a new line is beginning
	 * still inside of the tag.
	 */
	public static final int INTERNAL_INTAG					= -3;

	/**
	 * Token type specific to HTMLTokenMaker; this signals that the user has
	 * ended a line with an unclosed <code>&lt;script&gt;</code> tag.
	 */
	public static final int INTERNAL_INTAG_SCRIPT			= -4;

	/**
	 * Token type specifying we're in a double-qouted attribute in a
	 * script tag.
	 */
	public static final int INTERNAL_ATTR_DOUBLE_QUOTE_SCRIPT = -5;

	/**
	 * Token type specifying we're in a single-qouted attribute in a
	 * script tag.
	 */
	public static final int INTERNAL_ATTR_SINGLE_QUOTE_SCRIPT = -6;

	/**
	 * Token type specifying we're in JavaScript.
	 */
	public static final int INTERNAL_IN_JS					= -7;

	/**
	 * Token type specifying we're in a JavaScript multiline comment.
	 */
	public static final int INTERNAL_IN_JS_MLC				= -8;

	/**
	 * Token type specifying we're in an invalid multi-line JS string.
	 */
	public static final int INTERNAL_IN_JS_STRING_INVALID	= -9;

	/**
	 * Token type specifying we're in a valid multi-line JS string.
	 */
	public static final int INTERNAL_IN_JS_STRING_VALID		= -10;

	/**
	 * Token type specifying we're in an invalid multi-line JS single-quoted string.
	 */
	public static final int INTERNAL_IN_JS_CHAR_INVALID	= -11;

	/**
	 * Token type specifying we're in a valid multi-line JS single-quoted string.
	 */
	public static final int INTERNAL_IN_JS_CHAR_VALID		= -12;

	/**
	 * Whether closing markup tags are automatically completed for HTML.
	 */
	private static boolean completeCloseTags;

	/**
	 * When in the JS_STRING state, whether the current string is valid.
	 */
	private boolean validJSString;


	/**
	 * Constructor.  This must be here because JFlex does not generate a
	 * no-parameter constructor.
	 */
	public HTMLTokenMaker() {
		super();
	}


	/**
	 * Adds the token specified to the current linked list of tokens as an
	 * "end token;" that is, at <code>zzMarkedPos</code>.
	 *
	 * @param tokenType The token's type.
	 */
	private void addEndToken(int tokenType) {
		addToken(zzMarkedPos,zzMarkedPos, tokenType);
	}


	/**
	 * Adds the token specified to the current linked list of tokens.
	 *
	 * @param tokenType The token's type.
	 * @see #addToken(int, int, int)
	 */
	private void addHyperlinkToken(int start, int end, int tokenType) {
		int so = start + offsetShift;
		addToken(zzBuffer, start,end, tokenType, so, true);
	}


	/**
	 * Adds the token specified to the current linked list of tokens.
	 *
	 * @param tokenType The token's type.
	 */
	private void addToken(int tokenType) {
		addToken(zzStartRead, zzMarkedPos-1, tokenType);
	}


	/**
	 * Adds the token specified to the current linked list of tokens.
	 *
	 * @param tokenType The token's type.
	 */
	private void addToken(int start, int end, int tokenType) {
		int so = start + offsetShift;
		addToken(zzBuffer, start,end, tokenType, so);
	}


	/**
	 * Adds the token specified to the current linked list of tokens.
	 *
	 * @param array The character array.
	 * @param start The starting offset in the array.
	 * @param end The ending offset in the array.
	 * @param tokenType The token's type.
	 * @param startOffset The offset in the document at which this token
	 *                    occurs.
	 */
	public void addToken(char[] array, int start, int end, int tokenType, int startOffset) {
		super.addToken(array, start,end, tokenType, startOffset);
		zzStartRead = zzMarkedPos;
	}


	/**
	 * Sets whether markup close tags should be completed.  You might not want
	 * this to be the case, since some tags in standard HTML aren't usually
	 * closed.
	 *
	 * @return Whether closing markup tags are completed.
	 * @see #setCompleteCloseTags(boolean)
	 */
	public boolean getCompleteCloseTags() {
		return completeCloseTags;
	}


	/**
	 * Returns the first token in the linked list of tokens generated
	 * from <code>text</code>.  This method must be implemented by
	 * subclasses so they can correctly implement syntax highlighting.
	 *
	 * @param text The text from which to get tokens.
	 * @param initialTokenType The token type we should start with.
	 * @param startOffset The offset into the document at which
	 *        <code>text</code> starts.
	 * @return The first <code>Token</code> in a linked list representing
	 *         the syntax highlighted text.
	 */
	public Token getTokenList(Segment text, int initialTokenType, int startOffset) {

		resetTokenList();
		this.offsetShift = -text.offset + startOffset;

		// Start off in the proper state.
		int state = Token.NULL;
		switch (initialTokenType) {
			case Token.COMMENT_MULTILINE:
				state = COMMENT;
				start = text.offset;
				break;
			case Token.PREPROCESSOR:
				state = PI;
				start = text.offset;
				break;
			case Token.VARIABLE:
				state = DTD;
				start = text.offset;
				break;
			case INTERNAL_INTAG:
				state = INTAG;
				start = text.offset;
				break;
			case INTERNAL_INTAG_SCRIPT:
				state = INTAG_SCRIPT;
				start = text.offset;
				break;
			case INTERNAL_ATTR_DOUBLE:
				state = INATTR_DOUBLE;
				start = text.offset;
				break;
			case INTERNAL_ATTR_SINGLE:
				state = INATTR_SINGLE;
				start = text.offset;
				break;
			case INTERNAL_ATTR_DOUBLE_QUOTE_SCRIPT:
				state = INATTR_DOUBLE_SCRIPT;
				start = text.offset;
				break;
			case INTERNAL_ATTR_SINGLE_QUOTE_SCRIPT:
				state = INATTR_SINGLE_SCRIPT;
				start = text.offset;
				break;
			case INTERNAL_IN_JS:
				state = JAVASCRIPT;
				start = text.offset;
				break;
			case INTERNAL_IN_JS_MLC:
				state = JS_MLC;
				start = text.offset;
				break;
			case INTERNAL_IN_JS_STRING_INVALID:
				state = JS_STRING;
				validJSString = false;
				start = text.offset;
				break;
			case INTERNAL_IN_JS_STRING_VALID:
				state = JS_STRING;
				validJSString = true;
				start = text.offset;
				break;
			case INTERNAL_IN_JS_CHAR_INVALID:
				state = JS_CHAR;
				validJSString = false;
				start = text.offset;
				break;
			case INTERNAL_IN_JS_CHAR_VALID:
				state = JS_CHAR;
				validJSString = true;
				start = text.offset;
				break;
			default:
				state = Token.NULL;
		}

		s = text;
		try {
			yyreset(zzReader);
			yybegin(state);
			return yylex();
		} catch (IOException ioe) {
			ioe.printStackTrace();
			return new DefaultToken();
		}

	}


	/**
	 * Sets whether markup close tags should be completed.  You might not want
	 * this to be the case, since some tags in standard HTML aren't usually
	 * closed.
	 *
	 * @param complete Whether closing markup tags are completed.
	 * @see #getCompleteCloseTags()
	 */
	public static void setCompleteCloseTags(boolean complete) {
		completeCloseTags = complete;
	}


	/**
	 * Refills the input buffer.
	 *
	 * @return      <code>true</code> if EOF was reached, otherwise
	 *              <code>false</code>.
	 */
	private boolean zzRefill() {
		return zzCurrentPos>=s.offset+s.count;
	}


	/**
	 * Resets the scanner to read from a new input stream.
	 * Does not close the old reader.
	 *
	 * All internal variables are reset, the old input stream 
	 * <b>cannot</b> be reused (internal buffer is discarded and lost).
	 * Lexical state is set to <tt>YY_INITIAL</tt>.
	 *
	 * @param reader   the new input stream 
	 */
	public final void yyreset(java.io.Reader reader) {
		// 's' has been updated.
		zzBuffer = s.array;
		/*
		 * We replaced the line below with the two below it because zzRefill
		 * no longer "refills" the buffer (since the way we do it, it's always
		 * "full" the first time through, since it points to the segment's
		 * array).  So, we assign zzEndRead here.
		 */
		//zzStartRead = zzEndRead = s.offset;
		zzStartRead = s.offset;
		zzEndRead = zzStartRead + s.count - 1;
		zzCurrentPos = zzMarkedPos = zzPushbackPos = s.offset;
		zzLexicalState = YYINITIAL;
		zzReader = reader;
		zzAtBOL  = true;
		zzAtEOF  = false;
	}


%}

// HTML-specific stuff.
Whitespace			= ([ \t\f]+)
LineTerminator			= ([\n])
Identifier			= ([^ \t\n<&]+)
AmperItem				= ([&][^; \t]*[;]?)
InTagIdentifier		= ([^ \t\n\"\'/=>]+)
EndScriptTag			= ("</" [sS][cC][rR][iI][pP][tT] ">")


// JavaScript stuff.
Letter							= [A-Za-z]
NonzeroDigit						= [1-9]
Digit							= ("0"|{NonzeroDigit})
HexDigit							= ({Digit}|[A-Fa-f])
OctalDigit						= ([0-7])
EscapedSourceCharacter				= ("u"{HexDigit}{HexDigit}{HexDigit}{HexDigit})
NonSeparator						= ([^\t\f\r\n\ \(\)\{\}\[\]\;\,\.\=\>\<\!\~\?\:\+\-\*\/\&\|\^\%\"\']|"#"|"\\")
IdentifierStart					= ({Letter}|"_"|"$")
IdentifierPart						= ({IdentifierStart}|{Digit}|("\\"{EscapedSourceCharacter}))
JS_MLCBegin				= "/*"
JS_MLCEnd					= "*/"
JS_LineCommentBegin			= "//"
JS_IntegerHelper1			= (({NonzeroDigit}{Digit}*)|"0")
JS_IntegerHelper2			= ("0"(([xX]{HexDigit}+)|({OctalDigit}*)))
JS_IntegerLiteral			= ({JS_IntegerHelper1}[lL]?)
JS_HexLiteral				= ({JS_IntegerHelper2}[lL]?)
JS_FloatHelper1			= ([fFdD]?)
JS_FloatHelper2			= ([eE][+-]?{Digit}+{JS_FloatHelper1})
JS_FloatLiteral1			= ({Digit}+"."({JS_FloatHelper1}|{JS_FloatHelper2}|{Digit}+({JS_FloatHelper1}|{JS_FloatHelper2})))
JS_FloatLiteral2			= ("."{Digit}+({JS_FloatHelper1}|{JS_FloatHelper2}))
JS_FloatLiteral3			= ({Digit}+{JS_FloatHelper2})
JS_FloatLiteral			= ({JS_FloatLiteral1}|{JS_FloatLiteral2}|{JS_FloatLiteral3}|({Digit}+[fFdD]))
JS_ErrorNumberFormat		= (({JS_IntegerLiteral}|{JS_HexLiteral}|{JS_FloatLiteral}){NonSeparator}+)
JS_Separator				= ([\(\)\{\}\[\]\]])
JS_Separator2				= ([\;,.])
JS_NonAssignmentOperator		= ("+"|"-"|"<="|"^"|"++"|"<"|"*"|">="|"%"|"--"|">"|"/"|"!="|"?"|">>"|"!"|"&"|"=="|":"|">>"|"~"|"|"|"&&"|">>>")
JS_AssignmentOperator		= ("="|"-="|"*="|"/="|"|="|"&="|"^="|"+="|"%="|"<<="|">>="|">>>=")
JS_Operator				= ({JS_NonAssignmentOperator}|{JS_AssignmentOperator})
JS_Identifier				= ({IdentifierStart}{IdentifierPart}*)
JS_ErrorIdentifier			= ({NonSeparator}+)

URLGenDelim				= ([:\/\?#\[\]@])
URLSubDelim				= ([\!\$&'\(\)\*\+,;=])
URLUnreserved			= ({Letter}|"_"|{Digit}|[\-\.\~])
URLCharacter			= ({URLGenDelim}|{URLSubDelim}|{URLUnreserved}|[%])
URLCharacters			= ({URLCharacter}*)
URLEndCharacter			= ([\/\$]|{Letter}|{Digit})
URL						= (((https?|f(tp|ile))"://"|"www.")({URLCharacters}{URLEndCharacter})?)


%state COMMENT
%state PI
%state DTD
%state INTAG
%state INTAG_CHECK_TAG_NAME
%state INATTR_DOUBLE
%state INATTR_SINGLE
%state INTAG_SCRIPT
%state INATTR_DOUBLE_SCRIPT
%state INATTR_SINGLE_SCRIPT
%state JAVASCRIPT
%state JS_STRING
%state JS_CHAR
%state JS_MLC
%state JS_EOL_COMMENT


%%

<YYINITIAL> {
	"<!--"					{ start = zzMarkedPos-4; yybegin(COMMENT); }
	"<script"					{
							  addToken(zzStartRead,zzStartRead, Token.MARKUP_TAG_DELIMITER);
							  addToken(zzMarkedPos-6,zzMarkedPos-1, Token.MARKUP_TAG_NAME);
							  start = zzMarkedPos; yybegin(INTAG_SCRIPT);
							}
	"<!"						{ start = zzMarkedPos-2; yybegin(DTD); }
	"<?"						{ start = zzMarkedPos-2; yybegin(PI); }
	"<"({Letter}|{Digit})+		{
									int count = yylength();
									addToken(zzStartRead,zzStartRead, Token.MARKUP_TAG_DELIMITER);
									zzMarkedPos -= (count-1); //yypushback(count-1);
									yybegin(INTAG_CHECK_TAG_NAME);
								}
	"</"({Letter}|{Digit})+		{
									int count = yylength();
									addToken(zzStartRead,zzStartRead+1, Token.MARKUP_TAG_DELIMITER);
									zzMarkedPos -= (count-2); //yypushback(count-2);
									yybegin(INTAG_CHECK_TAG_NAME);
								}
	"<"							{ addToken(Token.MARKUP_TAG_DELIMITER); yybegin(INTAG); }
	"</"						{ addToken(Token.MARKUP_TAG_DELIMITER); yybegin(INTAG); }
	{LineTerminator}			{ addNullToken(); return firstToken; }
	{Identifier}				{ addToken(Token.IDENTIFIER); } // Catches everything.
	{AmperItem}				{ addToken(Token.DATA_TYPE); }
	{Whitespace}				{ addToken(Token.WHITESPACE); }
	<<EOF>>					{ addNullToken(); return firstToken; }
}

<COMMENT> {
	[^hwf\n\-]+				{}
	{URL}					{ int temp=zzStartRead; addToken(start,zzStartRead-1, Token.COMMENT_MULTILINE); addHyperlinkToken(temp,zzMarkedPos-1, Token.COMMENT_MULTILINE); start = zzMarkedPos; }
	[hwf]					{}
	{LineTerminator}			{ addToken(start,zzStartRead-1, Token.COMMENT_MULTILINE); return firstToken; }
	"-->"					{ yybegin(YYINITIAL); addToken(start,zzStartRead+2, Token.COMMENT_MULTILINE); }
	"-"						{}
	<<EOF>>					{ addToken(start,zzStartRead-1, Token.COMMENT_MULTILINE); return firstToken; }
}

<PI> {
	[^\n\?]+					{}
	{LineTerminator}			{ addToken(start,zzStartRead-1, Token.PREPROCESSOR); return firstToken; }
	"?>"						{ yybegin(YYINITIAL); addToken(start,zzStartRead+1, Token.PREPROCESSOR); }
	"?"						{}
	<<EOF>>					{ addToken(start,zzStartRead-1, Token.PREPROCESSOR); return firstToken; }
}

<DTD> {
	[^\n>]+					{}
	{LineTerminator}			{ addToken(start,zzStartRead-1, Token.VARIABLE); return firstToken; }
	">"						{ yybegin(YYINITIAL); addToken(start,zzStartRead, Token.VARIABLE); }
	<<EOF>>					{ addToken(start,zzStartRead-1, Token.VARIABLE); return firstToken; }
}

<INTAG_CHECK_TAG_NAME> {
	[Aa] |
	[aA][bB][bB][rR] |
	[aA][cC][rR][oO][nN][yY][mM] |
	[aA][dD][dD][rR][eE][sS][sS] |
	[aA][pP][pP][lL][eE][tT] |
	[aA][rR][eE][aA] |
	[aA][rR][tT][iI][cC][lL][eE] |
	[aA][sS][iI][dD][eE] |
	[aA][uU][dD][iI][oO] |
	[bB] |
	[bB][aA][sS][eE] |
	[bB][aA][sS][eE][fF][oO][nN][tT] |
	[bB][dD][oO] |
	[bB][gG][sS][oO][uU][nN][dD] |
	[bB][iI][gG] |
	[bB][lL][iI][nN][kK] |
	[bB][lL][oO][cC][kK][qQ][uU][oO][tT][eE] |
	[bB][oO][dD][yY] |
	[bB][rR] |
	[bB][uU][tT][tT][oO][nN] |
	[cC][aA][nN][vV][aA][sS] |
	[cC][aA][pP][tT][iI][oO][nN] |
	[cC][eE][nN][tT][eE][rR] |
	[cC][iI][tT][eE] |
	[cC][oO][dD][eE] |
	[cC][oO][lL] |
	[cC][oO][lL][gG][rR][oO][uU][pP] |
	[cC][oO][mM][mM][aA][nN][dD] |
	[cC][oO][mM][mM][eE][nN][tT] |
	[dD][dD] |
	[dD][aA][tT][aA][gG][rR][iI][dD] |
	[dD][aA][tT][aA][lL][iI][sS][tT] |
	[dD][aA][tT][aA][tT][eE][mM][pP][lL][aA][tT][eE] |
	[dD][eE][lL] |
	[dD][eE][tT][aA][iI][lL][sS] |
	[dD][fF][nN] |
	[dD][iI][aA][lL][oO][gG] |
	[dD][iI][rR] |
	[dD][iI][vV] |
	[dD][lL] |
	[dD][tT] |
	[eE][mM] |
	[eE][mM][bB][eE][dD] |
	[eE][vV][eE][nN][tT][sS][oO][uU][rR][cC][eE] |
	[fF][iI][eE][lL][dD][sS][eE][tT] |
	[fF][iI][gG][uU][rR][eE] |
	[fF][oO][nN][tT] |
	[fF][oO][oO][tT][eE][rR] |
	[fF][oO][rR][mM] |
	[fF][rR][aA][mM][eE] |
	[fF][rR][aA][mM][eE][sS][eE][tT] |
	[hH][123456] |
	[hH][eE][aA][dD] |
	[hH][eE][aA][dD][eE][rR] |
	[hH][rR] |
	[hH][tT][mM][lL] |
	[iI] |
	[iI][fF][rR][aA][mM][eE] |
	[iI][lL][aA][yY][eE][rR] |
	[iI][mM][gG] |
	[iI][nN][pP][uU][tT] |
	[iI][nN][sS] |
	[iI][sS][iI][nN][dD][eE][xX] |
	[kK][bB][dD] |
	[kK][eE][yY][gG][eE][nN] |
	[lL][aA][bB][eE][lL] |
	[lL][aA][yY][eE][rR] |
	[lL][eE][gG][eE][nN][dD] |
	[lL][iI] |
	[lL][iI][nN][kK] |
	[mM][aA][pP] |
	[mM][aA][rR][kK] |
	[mM][aA][rR][qQ][uU][eE][eE] |
	[mM][eE][nN][uU] |
	[mM][eE][tT][aA] |
	[mM][eE][tT][eE][rR] |
	[mM][uU][lL][tT][iI][cC][oO][lL] |
	[nN][aA][vV] |
	[nN][eE][sS][tT] |
	[nN][oO][bB][rR] |
	[nN][oO][eE][mM][bB][eE][dD] |
	[nN][oO][fF][rR][aA][mM][eE][sS] |
	[nN][oO][lL][aA][yY][eE][rR] |
	[nN][oO][sS][cC][rR][iI][pP][tT] |
	[oO][bB][jJ][eE][cC][tT] |
	[oO][lL] |
	[oO][pP][tT][gG][rR][oO][uU][pP] |
	[oO][pP][tT][iI][oO][nN] |
	[oO][uU][tT][pP][uU][tT] |
	[pP] |
	[pP][aA][rR][aA][mM] |
	[pP][lL][aA][iI][nN][tT][eE][xX][tT] |
	[pP][rR][eE] |
	[pP][rR][oO][gG][rR][eE][sS][sS] |
	[qQ] |
	[rR][uU][lL][eE] |
	[sS] |
	[sS][aA][mM][pP] |
	[sS][cC][rR][iI][pP][tT] |
	[sS][eE][cC][tT][iI][oO][nN] |
	[sS][eE][lL][eE][cC][tT] |
	[sS][eE][rR][vV][eE][rR] |
	[sS][mM][aA][lL][lL] |
	[sS][oO][uU][rR][cC][eE] |
	[sS][pP][aA][cC][eE][rR] |
	[sS][pP][aA][nN] |
	[sS][tT][rR][iI][kK][eE] |
	[sS][tT][rR][oO][nN][gG] |
	[sS][tT][yY][lL][eE] |
	[sS][uU][bB] |
	[sS][uU][pP] |
	[tT][aA][bB][lL][eE] |
	[tT][bB][oO][dD][yY] |
	[tT][dD] |
	[tT][eE][xX][tT][aA][rR][eE][aA] |
	[tT][fF][oO][oO][tT] |
	[tT][hH] |
	[tT][hH][eE][aA][dD] |
	[tT][iI][mM][eE] |
	[tT][iI][tT][lL][eE] |
	[tT][rR] |
	[tT][tT] |
	[uU] |
	[uU][lL] |
	[vV][aA][rR] |
	[vV][iI][dD][eE][oO]    { addToken(Token.MARKUP_TAG_NAME); }
	{InTagIdentifier}		{ /* A non-recognized HTML tag name */ yypushback(yylength()); yybegin(INTAG); }
	.						{ /* Shouldn't happen */ yypushback(1); yybegin(INTAG); }
	<<EOF>>					{ addToken(zzMarkedPos,zzMarkedPos, INTERNAL_INTAG); return firstToken; }
}

<INTAG> {
	"/"						{ addToken(Token.MARKUP_TAG_DELIMITER); }
	{InTagIdentifier}			{ addToken(Token.MARKUP_TAG_ATTRIBUTE); }
	{Whitespace}				{ addToken(Token.WHITESPACE); }
	"="						{ addToken(Token.OPERATOR); }
	"/>"						{ yybegin(YYINITIAL); addToken(Token.MARKUP_TAG_DELIMITER); }
	">"						{ yybegin(YYINITIAL); addToken(Token.MARKUP_TAG_DELIMITER); }
	[\"]						{ start = zzMarkedPos-1; yybegin(INATTR_DOUBLE); }
	[\']						{ start = zzMarkedPos-1; yybegin(INATTR_SINGLE); }
	<<EOF>>					{ addToken(zzMarkedPos,zzMarkedPos, INTERNAL_INTAG); return firstToken; }
}

<INATTR_DOUBLE> {
	[^\"]*						{}
	[\"]						{ yybegin(INTAG); addToken(start,zzStartRead, Token.MARKUP_TAG_ATTRIBUTE_VALUE); }
	<<EOF>>						{ addToken(start,zzStartRead-1, Token.MARKUP_TAG_ATTRIBUTE_VALUE); addEndToken(INTERNAL_ATTR_DOUBLE); return firstToken; }
}

<INATTR_SINGLE> {
	[^\']*						{}
	[\']						{ yybegin(INTAG); addToken(start,zzStartRead, Token.MARKUP_TAG_ATTRIBUTE_VALUE); }
	<<EOF>>						{ addToken(start,zzStartRead-1, Token.MARKUP_TAG_ATTRIBUTE_VALUE); addEndToken(INTERNAL_ATTR_SINGLE); return firstToken; }
}

<INTAG_SCRIPT> {
	{InTagIdentifier}			{ addToken(Token.MARKUP_TAG_ATTRIBUTE); }
	"/>"					{	addToken(Token.MARKUP_TAG_DELIMITER); yybegin(YYINITIAL); }
	"/"						{ addToken(Token.MARKUP_TAG_DELIMITER); } // Won't appear in valid HTML.
	{Whitespace}				{ addToken(Token.WHITESPACE); }
	"="						{ addToken(Token.OPERATOR); }
	">"						{ yybegin(JAVASCRIPT); addToken(Token.MARKUP_TAG_DELIMITER); }
	[\"]						{ start = zzMarkedPos-1; yybegin(INATTR_DOUBLE_SCRIPT); }
	[\']						{ start = zzMarkedPos-1; yybegin(INATTR_SINGLE_SCRIPT); }
	<<EOF>>					{ addToken(zzMarkedPos,zzMarkedPos, INTERNAL_INTAG_SCRIPT); return firstToken; }
}

<INATTR_DOUBLE_SCRIPT> {
	[^\"]*						{}
	[\"]						{ yybegin(INTAG_SCRIPT); addToken(start,zzStartRead, Token.MARKUP_TAG_ATTRIBUTE_VALUE); }
	<<EOF>>						{ addToken(start,zzStartRead-1, Token.MARKUP_TAG_ATTRIBUTE_VALUE); addEndToken(INTERNAL_ATTR_DOUBLE_QUOTE_SCRIPT); return firstToken; }
}

<INATTR_SINGLE_SCRIPT> {
	[^\']*						{}
	[\']						{ yybegin(INTAG_SCRIPT); addToken(start,zzStartRead, Token.MARKUP_TAG_ATTRIBUTE_VALUE); }
	<<EOF>>						{ addToken(start,zzStartRead-1, Token.MARKUP_TAG_ATTRIBUTE_VALUE); addEndToken(INTERNAL_ATTR_SINGLE_QUOTE_SCRIPT); return firstToken; }
}

<JAVASCRIPT> {

	{EndScriptTag}				{
								  yybegin(YYINITIAL);
								  addToken(zzStartRead,zzStartRead+1, Token.MARKUP_TAG_DELIMITER);
								  addToken(zzMarkedPos-7,zzMarkedPos-2, Token.MARKUP_TAG_NAME);
								  addToken(zzMarkedPos-1,zzMarkedPos-1, Token.MARKUP_TAG_DELIMITER);
								}

	// ECMA keywords.
	"break" |
	"continue" |
	"delete" |
	"else" |
	"for" |
	"function" |
	"if" |
	"in" |
	"new" |
	"return" |
	"this" |
	"typeof" |
	"var" |
	"void" |
	"while" |
	"with"						{ addToken(Token.RESERVED_WORD); }

	// Reserved (but not yet used) ECMA keywords.
	"abstract"					{ addToken(Token.RESERVED_WORD); }
	"boolean"						{ addToken(Token.DATA_TYPE); }
	"byte"						{ addToken(Token.DATA_TYPE); }
	"case"						{ addToken(Token.RESERVED_WORD); }
	"catch"						{ addToken(Token.RESERVED_WORD); }
	"char"						{ addToken(Token.DATA_TYPE); }
	"class"						{ addToken(Token.RESERVED_WORD); }
	"const"						{ addToken(Token.RESERVED_WORD); }
	"debugger"					{ addToken(Token.RESERVED_WORD); }
	"default"						{ addToken(Token.RESERVED_WORD); }
	"do"							{ addToken(Token.RESERVED_WORD); }
	"double"						{ addToken(Token.DATA_TYPE); }
	"enum"						{ addToken(Token.RESERVED_WORD); }
	"export"						{ addToken(Token.RESERVED_WORD); }
	"extends"						{ addToken(Token.RESERVED_WORD); }
	"final"						{ addToken(Token.RESERVED_WORD); }
	"finally"						{ addToken(Token.RESERVED_WORD); }
	"float"						{ addToken(Token.DATA_TYPE); }
	"goto"						{ addToken(Token.RESERVED_WORD); }
	"implements"					{ addToken(Token.RESERVED_WORD); }
	"import"						{ addToken(Token.RESERVED_WORD); }
	"instanceof"					{ addToken(Token.RESERVED_WORD); }
	"int"						{ addToken(Token.DATA_TYPE); }
	"interface"					{ addToken(Token.RESERVED_WORD); }
	"long"						{ addToken(Token.DATA_TYPE); }
	"native"						{ addToken(Token.RESERVED_WORD); }
	"package"						{ addToken(Token.RESERVED_WORD); }
	"private"						{ addToken(Token.RESERVED_WORD); }
	"protected"					{ addToken(Token.RESERVED_WORD); }
	"public"						{ addToken(Token.RESERVED_WORD); }
	"short"						{ addToken(Token.DATA_TYPE); }
	"static"						{ addToken(Token.RESERVED_WORD); }
	"super"						{ addToken(Token.RESERVED_WORD); }
	"switch"						{ addToken(Token.RESERVED_WORD); }
	"synchronized"					{ addToken(Token.RESERVED_WORD); }
	"throw"						{ addToken(Token.RESERVED_WORD); }
	"throws"						{ addToken(Token.RESERVED_WORD); }
	"transient"					{ addToken(Token.RESERVED_WORD); }
	"try"						{ addToken(Token.RESERVED_WORD); }
	"volatile"					{ addToken(Token.RESERVED_WORD); }
	"null"						{ addToken(Token.RESERVED_WORD); }

	// Literals.
	"false" |
	"true"						{ addToken(Token.LITERAL_BOOLEAN); }
	"NaN"						{ addToken(Token.RESERVED_WORD); }
	"Infinity"					{ addToken(Token.RESERVED_WORD); }

	// Functions.
	"eval" |
	"parseInt" |
	"parseFloat" |
	"escape" |
	"unescape" |
	"isNaN" |
	"isFinite"					{ addToken(Token.FUNCTION); }

	{LineTerminator}				{ addEndToken(INTERNAL_IN_JS); return firstToken; }
	{JS_Identifier}				{ addToken(Token.IDENTIFIER); }
	{Whitespace}					{ addToken(Token.WHITESPACE); }

	/* String/Character literals. */
	[\']							{ start = zzMarkedPos-1; validJSString = true; yybegin(JS_CHAR); }
	[\"]							{ start = zzMarkedPos-1; validJSString = true; yybegin(JS_STRING); }

	/* Comment literals. */
	"/**/"						{ addToken(Token.COMMENT_MULTILINE); }
	{JS_MLCBegin}					{ start = zzMarkedPos-2; yybegin(JS_MLC); }
	{JS_LineCommentBegin}			{ start = zzMarkedPos-2; yybegin(JS_EOL_COMMENT); }

	/* Separators. */
	{JS_Separator}					{ addToken(Token.SEPARATOR); }
	{JS_Separator2}				{ addToken(Token.IDENTIFIER); }

	/* Operators. */
	{JS_Operator}					{ addToken(Token.OPERATOR); }

	/* Numbers */
	{JS_IntegerLiteral}				{ addToken(Token.LITERAL_NUMBER_DECIMAL_INT); }
	{JS_HexLiteral}				{ addToken(Token.LITERAL_NUMBER_HEXADECIMAL); }
	{JS_FloatLiteral}				{ addToken(Token.LITERAL_NUMBER_FLOAT); }
	{JS_ErrorNumberFormat}			{ addToken(Token.ERROR_NUMBER_FORMAT); }

	{JS_ErrorIdentifier}			{ addToken(Token.ERROR_IDENTIFIER); }

	/* Ended with a line not in a string or comment. */
	<<EOF>>						{ addEndToken(INTERNAL_IN_JS); return firstToken; }

	/* Catch any other (unhandled) characters and flag them as bad. */
	.							{ addToken(Token.ERROR_IDENTIFIER); }

}

<JS_STRING> {
	[^\n\\\"]+				{}
	\n						{ addToken(start,zzStartRead-1, Token.ERROR_STRING_DOUBLE); addEndToken(INTERNAL_IN_JS); return firstToken; }
	\\x{HexDigit}{2}		{}
	\\x						{ /* Invalid latin-1 character \xXX */ validJSString = false; }
	\\u{HexDigit}{4}		{}
	\\u						{ /* Invalid Unicode character \\uXXXX */ validJSString = false; }
	\\.						{ /* Skip all escaped chars. */ }
	\\						{ /* Line ending in '\' => continue to next line. */
								if (validJSString) {
									addToken(start,zzStartRead, Token.LITERAL_STRING_DOUBLE_QUOTE);
									addEndToken(INTERNAL_IN_JS_STRING_VALID);
								}
								else {
									addToken(start,zzStartRead, Token.ERROR_STRING_DOUBLE);
									addEndToken(INTERNAL_IN_JS_STRING_INVALID);
								}
								return firstToken;
							}
	\"						{ int type = validJSString ? Token.LITERAL_STRING_DOUBLE_QUOTE : Token.ERROR_STRING_DOUBLE; addToken(start,zzStartRead, type); yybegin(JAVASCRIPT); }
	<<EOF>>					{ addToken(start,zzStartRead-1, Token.ERROR_STRING_DOUBLE); addEndToken(INTERNAL_IN_JS); return firstToken; }
}

<JS_CHAR> {
	[^\n\\\']+				{}
	\n						{ addToken(start,zzStartRead-1, Token.ERROR_CHAR); addEndToken(INTERNAL_IN_JS); return firstToken; }
	\\x{HexDigit}{2}		{}
	\\x						{ /* Invalid latin-1 character \xXX */ validJSString = false; }
	\\u{HexDigit}{4}		{}
	\\u						{ /* Invalid Unicode character \\uXXXX */ validJSString = false; }
	\\.						{ /* Skip all escaped chars. */ }
	\\						{ /* Line ending in '\' => continue to next line. */
								if (validJSString) {
									addToken(start,zzStartRead, Token.LITERAL_CHAR);
									addEndToken(INTERNAL_IN_JS_CHAR_VALID);
								}
								else {
									addToken(start,zzStartRead, Token.ERROR_CHAR);
									addEndToken(INTERNAL_IN_JS_CHAR_INVALID);
								}
								return firstToken;
							}
	\'						{ int type = validJSString ? Token.LITERAL_CHAR : Token.ERROR_CHAR; addToken(start,zzStartRead, type); yybegin(JAVASCRIPT); }
	<<EOF>>					{ addToken(start,zzStartRead-1, Token.ERROR_CHAR); addEndToken(INTERNAL_IN_JS); return firstToken; }
}

<JS_MLC> {
	// JavaScript MLC's.  This state is essentially Java's MLC state.
	[^hwf\n\*]+				{}
	{URL}					{ int temp=zzStartRead; addToken(start,zzStartRead-1, Token.COMMENT_EOL); addHyperlinkToken(temp,zzMarkedPos-1, Token.COMMENT_EOL); start = zzMarkedPos; }
	[hwf]					{}
	\n							{ addToken(start,zzStartRead-1, Token.COMMENT_MULTILINE); addEndToken(INTERNAL_IN_JS_MLC); return firstToken; }
	{JS_MLCEnd}					{ yybegin(JAVASCRIPT); addToken(start,zzStartRead+1, Token.COMMENT_MULTILINE); }
	\*							{}
	<<EOF>>						{ addToken(start,zzStartRead-1, Token.COMMENT_MULTILINE); addEndToken(INTERNAL_IN_JS_MLC); return firstToken; }
}

<JS_EOL_COMMENT> {
	[^hwf<\n]+				{}
	{URL}					{ int temp=zzStartRead; addToken(start,zzStartRead-1, Token.COMMENT_EOL); addHyperlinkToken(temp,zzMarkedPos-1, Token.COMMENT_EOL); start = zzMarkedPos; }
	[hwf]					{}
	{EndScriptTag}			{
							  yybegin(YYINITIAL);
							  int temp = zzStartRead;
							  addToken(start,zzStartRead-1, Token.COMMENT_EOL);
							  addToken(temp,temp+1, Token.MARKUP_TAG_DELIMITER);
							  addToken(zzMarkedPos-7,zzMarkedPos-2, Token.MARKUP_TAG_NAME);
							  addToken(zzMarkedPos-1,zzMarkedPos-1, Token.MARKUP_TAG_DELIMITER);
							}
	"<"						{}
	\n						{ addToken(start,zzStartRead-1, Token.COMMENT_EOL); addEndToken(INTERNAL_IN_JS); return firstToken; }
	<<EOF>>					{ addToken(start,zzStartRead-1, Token.COMMENT_EOL); addEndToken(INTERNAL_IN_JS); return firstToken; }

}
