" Vim global plugin for inline browsing of stack overflow results
" Used NERD tree as a reference for the menuing. http://www.vim.org/scripts/script.php?script_id=1658
" Last Change: 2010 Jun 8
" Maintainer:  Matt Wilson <matt@copypastel.com>, Ecin <ecin@copypastel.com>
" License: This file is placed in under the Vim License <http://vimdoc.sourceforge.net/htmldoc/uganda.html>

let s:vim_overflow_version = '0.1.0'

"SECTION: Initilization {{{1
"================================================
if exists("loaded_overflow")
  finish
endif
let loaded_overflow = 1

let s:usr_cpo = &cpo
set cpo&vim

"SECTION: User Entrance Functions {{{1
"================================================
"FUNCTION: SearchStackOverflow(text) {{{2
"Called by user when executes Vimoverflow <searchterm> or Vo <searchterm>
"Opens a new window if not created and populates with search results
function s:SearchStackOverflow(text)
  call s:CreateResultWin()

  let cmd = join(["overflow_plugin/bin/vo", '"' . a:text . '"'], " ")
  let query_result = system(cmd)

  let query = s:Query.New(query_result)
  call s:BindKeys(query)
  call query.drawTitles()
endfunction

"FUNCTION: ShowAnswer() {{{2
"Called when user presses enter on a question they wish to see the answer of
function s:ShowAnswer()
  call b:currentQuery.showAnswer(line("."))
endfunction

"FUNCTION: ShowQuestion() {{{2
"Called when a user presses the l key on a title they wish to see more info of
function s:ShowQuestion()
  call b:currentQuery.showQuestion(line("."))
endfunction

"FUNCTION: HideQuestion() {{{2
"Called when a user presses the h key on a title or body they wish to collaps
"Does nothing if the question is already collapsed.
function s:HideQuestion()
  call b:currentQuery.hideQuestion(line("."))
endfunction

"SECTION: Support Functions {{{1
"================================================
"FUNCTION: CreateResultWin() {{{2
"Creates or changes focus to the result buffer
function s:CreateResultWin()
  let bufname = 'results.stackoverflow'
  badd  results.stackoverflow
  silent buffer results.stackoverflow
endfunction

"FUNCTION: BindKeys(query) {{{2
"With the result buffer selected this will store the query and map the
"navigation functions to the proper keypresses
"
"query = a Query class with the results to navigate
function s:BindKeys(query)
  let b:currentQuery = a:query
  exec "nnoremap <silent> <buffer> <cr> :call <SID>ShowAnswer()<cr>" 
  exec "nnoremap <silent> <buffer> l :call <SID>ShowQuestion()<cr>"
  exec "nnoremap <silent> <buffer> h :call <SID>HideQuestion()<cr>"
endfunction

"SECTION: Classes {{{1
"================================================
"CLASS: Query {{{2
"Query contains the titles of the posts, the post bodies, and the responses
let s:Query = {}

"FUNCTION: Query.New(raw) {{{3
"Create a new query
"
"raw = raw text result returned from perl query.
function s:Query.New(raw)
  let newQuery      = copy(self)
  let parsed_result = split(a:raw,"--END--\n--SECTION--\n")

  let newQuery.titles    = split(parsed_result[0],"--END--\n")
  let newQuery.questions = split(parsed_result[1],"--END--\n")
  let newQuery.answers   = split(parsed_result[2],"--END--\n")
  let newQuery.cursor    = 0

  let newQuery.expanded_indexes = []
  let i = 0
  while i < len(newQuery.questions)
    call insert(newQuery.expanded_indexes, 0)
    let i += 1
  endwhile

  return newQuery
endfunction

"FUNCTION: Query.drawTitles() {{{3
"Draws the titles and expanded posts
function s:Query.drawTitles()
  " Draw the results here
  setlocal modifiable

  " delete all lines
  silent 1,$delete _
  
  let i = 0
  while i < len(self.titles)
    let @o = self.titles[i]
    silent put o
    if self.expanded_indexes[i]
      for line in split(self.questions[i],"\n")
        let @o = "  " . line
        silent put o
      endfor
    endif

    let i += 1
  endwhile

  "delete the blank line at the top of the buffer
  silent 1,1delete _

  call cursor(self.cursor, col("."))
  setlocal nomodifiable
endfunction

"FUNCTION: Query.showAnswer(line) {{{3
"Draws the answer in the current buffer
" Args:
" line = line number that the cursor was on
function s:Query.showAnswer(line)
  let index = self._indexFromLine(a:line)
  setlocal modifiable
  silent 1,$delete _

  let @o = self.answers[index]
  silent put o

  " Delete first line
  silent 1,1delete _
  setlocal nomodifiable

  syn match wtfMan /<p>.\{-}<\/p>/
  hi def wtfMan term=bold cterm=bold
endfunction

"FUNCTION: Query.showQuestion(line) {{{3
"expands the post title to show the complete question and redraws the buffer
" Args:
" line = line number that the cursor was on
function s:Query.showQuestion(line)
  let index = self._indexFromLine(a:line)
  let self.expanded_indexes[index] = 1
  let self.cursor = a:line
  call self.drawTitles()
endfunction

"FUNCTION: Query.hideQuestion(line) {{{3
"contracts the post title to hide the complete question and redraws the buffer
" Args:
" line = line number that the cursor was on
function s:Query.hideQuestion(line)
  let index = self._indexFromLine(a:line)
  let self.cursor = self._titleLineNumberFromIndex(index)
  let self.expanded_indexes[index] = 0
  call self.drawTitles()
endfunction

"FUNCTION: Query._indexFromLine(line) {{{3
"returns the question number
function s:Query._indexFromLine(line)
  let realindex = 0
  let line = a:line
  echo self.expanded_indexes
  while realindex < line
    if self.expanded_indexes[realindex]
      " Subtract out the number of lines in the expanded view
      let line -= len(split(self.questions[realindex],"\n"))
    endif
    let realindex += 1 
  endwhile

  return realindex - 1
endfunction

"FUNCTION: Query._titleLineNumberFromIndex(index) {{{3
"returns the current title line number 
"used when we want to know the line of a title
function s:Query._titleLineNumberFromIndex(index)
  let result = a:index
  let i = 0
  while i < a:index
    if self.expanded_indexes[i]
      let result += len(split(self.questions[i],"\n"))
    endif

    let i += 1
  endwhile

  return result + 1
endfunction

"SECTION: Command Mappings {{{1
"================================================
if !exists(":Vimoverflow")
  command -nargs=1 Vimoverflow :call s:SearchStackOverflow(<q-args>)
endif

if !exists(":Vo")
  command -nargs=1 Vo :call s:SearchStackOverflow(<q-args>)
endif

"restore user compatibility options
let &cpo = s:usr_cpo

