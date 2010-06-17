" Vim global plugin for inline browsing of stack overflow results
" Used NERD tree as a reference for the menuing. http://www.vim.org/scripts/script.php?script_id=1658
" Last Change: 2010 Jun 8
" Maintainer:  Matt Wilson <matt@copypastel.com>, Ecin <ecin@copypastel.com>
" License: This file is placed in under the Vim License <http://vimdoc.sourceforge.net/htmldoc/uganda.html>

let s:vim_overflow_version = '0.1.0'

"SECTION: Initilization                                                   {{{1
"================================================
if exists("loaded_overflow")
  finish
endif
let loaded_overflow = 1

let s:usr_cpo = &cpo
set cpo&vim

"SECTION: User Entrance Functions                                         {{{1
"================================================
"FUNCTION: SearchStackOverflow(text)                                      {{{2
"Called by user when executes Vimoverflow <searchterm> or Vo <searchterm>
"Opens a new window if not created and populates with search results
function s:SearchStackOverflow(text)
  call s:CreateResultWin()

  let cmd = join([$HOME . "/.vim/plugin/vimoverflow/bin/vo", '"' . a:text . '"'], " ")
  let query_result = system(cmd)

  let query = s:Query.New(query_result)
  call s:BindKeys(query)
  call query.render()
endfunction

"FUNCTION: EnterPressed()                                                 {{{2
"Called when user presses enter on a question they wish to see the answer of
function s:EnterPressed()
  call b:currentQuery.enterPressed(line("."))
endfunction

let s:BufVisible = 0
let s:BufCreated = 0
"SECTION: Support Functions                                               {{{1
"================================================
"FUNCTION: CreateResultWin()                                              {{{2
"Creates or changes focus to the result buffer
"Makes the buffer temporary and will always use split buffer
function s:CreateResultWin()
  if !s:BufCreated
    badd results.stackoverflow
    let s:BufCreated = 1
  endif
  if !s:BufVisible 
    sb!  results.stackoverflow
    let s:BufVisible = 1
    set bufhidden=hide
    set buftype=nofile
    setlocal noswapfile
    autocmd BufHidden results.stackoverflow call s:BufferGone()
  endif
endfunction

"FUNCTION: BufferGone()
"Event which runs when the report buffer exits
function s:BufferGone()
  let s:BufVisible = 0
endfunction

"FUNCTION: BindKeys(query)                                                {{{2
"With the result buffer selected this will store the query and map the
"navigation functions to the proper keypresses
"
"query = a Query class with the results to navigate
function s:BindKeys(query)
  let b:currentQuery = a:query
  exec "nnoremap <silent> <buffer> <cr> :call <SID>EnterPressed()<cr>" 
endfunction

"SECTION: Classes                                                         {{{1
"================================================
"CLASS: Question                                                          {{{2
"Question contains the title, body, and answer of the posts
let s:Question = {}
"FUNCTION: s:Question.New(title,body,answer)                              {{{3
" Args:
" title = title of the question
" body  = body of the question
" answer = answer of the question
function s:Question.New(title,body,answer)
  let newQuestion = copy(self)

  let newQuestion.title         = a:title
  let newQuestion.body          = a:body
  let newQuestion.answer        = a:answer
  let newQuestion.show_question = 0
  let newQuestion.show_answer   = 0
  let newQuestion.lines         = 3

  return newQuestion
endfunction

"FUNCTION: s:Question.render(indent)                                      {{{3
"Renders the menu
" Args:
" level of indent we want the menu to be on
function s:Question.render(indent)
  let result = "(solved) " . self.title . "\n"
  if self.show_question
    let result = result . a:indent . "-- Hide Question --" . "\n"
    for line in split(self.body,"\n")
      let result = result . a:indent . line . "\n"
    endfor
  else
    let result = result . a:indent . "-- Show Question --" . "\n"
  endif
  
  "Have to put the \n in reverse order here since the put command
  "inserts a new line.  Answer will not end with a \n
  if self.show_answer
    let result = result . a:indent . "-- Hide Answer --" 
    for line in split(self.answer,"\n")
      let result = result . "\n" . a:indent . line
    endfor
  else
    let result = result . a:indent . "-- Show Answer --"
  endif
  
  let self.lines = len(split(result,"\n"))

  return result
endfunction

"FUNCTION: Question.enterPressed(line)                                    {{{3
"changes options which affect render
" Args:
" line = line relative to this question
function s:Question.enterPressed(line)
  echo a:line
  if self._body_selected(a:line)
    let self.show_question = !self.show_question
  elseif self._answer_selected(a:line)
    let self.show_answer = !self.show_answer
  endif
endfunction

"FUNCTION: Question._body_selected(line)                                  {{{3
"returns true if the line given is on the body
" Args:
" line = line lerative to this question
function s:Question._body_selected(line)
  if a:line == 2
    return 1
  endif
  return 0
endfunction

"FUNCTION: Question._answer_selected(line)                                {{{3
"returns true if the line given is on the answer
" Args:
" line = line lerative to this question
function s:Question._answer_selected(line)
  let selection = a:line
  if self.show_question
    let selection -= len(split(self.body,"\n"))    
  endif
  if selection == 3
    return 1
  endif
  return 0
endfunction

"CLASS: Query                                                             {{{2
"Query contains the titles of the posts, the post bodies, and the responses
let s:Query = {}
"FUNCTION: Query.New(raw)                                                 {{{3
"Create a new query
"
" Args:
" raw = raw text result returned from perl query.
function s:Query.New(raw)
  let newQuery      = copy(self)
  let parsed_result = split(a:raw,"--END--\n--SECTION--\n")

  let newQuery.cursor = 0

  let titles    = split(parsed_result[0],"--END--\n")
  let bodies    = split(parsed_result[1],"--END--\n")
  let answers   = split(parsed_result[2],"--END--\n")

  "Initialize the questions parsed from raw
  let newQuery.questions = []
  for i in range(len(titles))
    call insert(newQuery.questions,s:Question.New(titles[i],bodies[i],answers[i]))
  endfor

  let newQuery.question_to_line = []
  for i in range(len(newQuery.questions))
    call insert(newQuery.question_to_line,0)
  endfor

  return newQuery
endfunction

"FUNCTION: Query.render()                                                 {{{3
"Draws the titles and expanded posts
function s:Query.render()
  " Draw the results here
  setlocal modifiable

  " delete all lines
  silent 1,$delete _
  
  for question in self.questions
    let @o = self._formatText(question.render("  "))
    silent put o
  endfor

  "delete the blank line at the top of the buffer
  silent 1,1delete _

  call cursor(self.cursor, col("."))
  setlocal nomodifiable
  
  syn match VoOption /-- Show Question --/
  syn match VoOption /-- Hide Question --/
  syn match VoOption /-- Show Answer --/
  syn match VoOption /-- Hide Answer --/
  hi def VoOption ctermfg=Yellow

  syn match VoTitle /(solved)/
  hi def VoTitle ctermfg=Green

  syn match VoTitlePend /(pending)/
  hi def VoTitlePend ctermfg=Blue
endfunction

"FUNCTION: Query.enterPressed(line)                                       {{{3
"Figures out which selection was made and displays/hides the question/answer
" Args:
" line = line number that the cursor was on
function s:Query.enterPressed(line)
  let self.cursor = a:line
  let relLine = a:line
  for question in self.questions
    if relLine - question.lines <= 0
      call question.enterPressed(relLine)
      break
    endif
    let relLine -= question.lines
  endfor

  call self.render()
endfunction

"FUNCTION: Query.showQuestion(line)                                       {{{3
"expands the post title to show the complete question and redraws the buffer
" Args:
" line = line number that the cursor was on
function s:Query.showQuestion(line)
  let index = self._indexFromLine(a:line)
  let self.expanded_indexes[index] = 1
  let self.cursor = a:line
  call self.drawTitles()
endfunction

"FUNCTION: Query.hideQuestion(line)                                       {{{3
"contracts the post title to hide the complete question and redraws the buffer
" Args:
" line = line number that the cursor was on
function s:Query.hideQuestion(line)
  let index = self._indexFromLine(a:line)
  let self.cursor = self._titleLineNumberFromIndex(index)
  let self.expanded_indexes[index] = 0
  call self.drawTitles()
endfunction

"FUNCTION: Query._indexFromLine(line)                                     {{{3
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

"FUNCTION: Query._titleLineNumberFromIndex(index)                         {{{3
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

"FUNCTION: Query._formatText(text)                                        {{{3
"Formats the text and returns the proper result
function s:Query._formatText(text)
  let result = substitute(a:text,"<p>","","g")
  let result = substitute(result,"</p>","","g")
  let result = substitute(result,"<b>","","g")
  let result = substitute(result,"</b>","","g")
  let result = substitute(result,"<strong>","","g")
  let result = substitute(result,"</strong>","","g")
  let result = substitute(result,"<i>","","g")
  let result = substitute(result,"</i>","","g")
  let result = substitute(result,"<ol>","","g")
  let result = substitute(result,"</ol>","","g")
  let result = substitute(result,"<li>","","g")
  let result = substitute(result,"</li>","","g")
  return result
endfunction
"SECTION: Command Mappings                                                {{{1
"================================================
if !exists(":Vimoverflow")
  command -nargs=1 Vimoverflow :call s:SearchStackOverflow(<q-args>)
endif

if !exists(":Vo")
  command -nargs=1 Vo :call s:SearchStackOverflow(<q-args>)
endif

"restore user compatibility options
let &cpo = s:usr_cpo

