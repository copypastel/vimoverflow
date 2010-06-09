" Vim global plugin for inline browsing of stack overflow results
" Used NERD tree as a reference for the menuing. http://www.vim.org/scripts/script.php?script_id=1658
" Last Change: 2010 Jun 8
" Maintainer:  Matt Wilson <matt@copypastel.com>, Ecin <ecin@copypastel.com>
" License: This file is placed in under the Vim License <http://vimdoc.sourceforge.net/htmldoc/uganda.html>

if exists("loaded_overflow")
  finish
endif
let loaded_overflow = 1



function s:SearchStackOverflow(text)
  call s:CreateResultWin()

  let cmd = join(["overflow_plugin/bin/vo", '"' . a:text . '"'], " ")
  let query_result = system(cmd)

  let query = s:Query.New(query_result)
  call s:BindKeys(query)
  call query.showTitles()
endfunction

function s:CreateResultWin()
  let bufname = 'results.stackoverflow'
  badd  results.stackoverflow
  silent buffer results.stackoverflow
endfunction

function s:BindKeys(query)
  let b:currentQuery = a:query
  exec "nnoremap <silent> <buffer> <cr> :call <SID>ShowAnswer()<cr>" 
  exec "nnoremap <silent> <buffer> l :call <SID>ShowQuestion()<cr>"
  exec "nnoremap <silent> <buffer> h :call <SID>HideQuestion()<cr>"
endfunction

function s:ShowAnswer()
  call b:currentQuery.showAnswer(line("."))
endfunction

function s:ShowQuestion()
  call b:currentQuery.showQuestion(line("."))
endfunction

function s:HideQuestion()
  call b:currentQuery.hideQuestion(line("."))
endfunction

let s:Query = {}

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

function s:Query.showTitles()
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
        let @o = " | " . line
        silent put o
      endfor
    endif

    let i += 1
  endwhile

  "delete the blank line at the top of the buffer
  silent 1,1delete _

  call cursor(self.cursor, col("."))
"call setline(line(".")+1, a:opts)
 
  setlocal nomodifiable
endfunction

function s:Query.showAnswer(line)
  let index = self._unexpandedIndex(a:line)
  setlocal modifiable
  silent 1,$delete _

  let @o = self.answers[index]
  silent put o

  silent 1,1delete _
  setlocal nomodifiable
endfunction

function s:Query.showQuestion(line)
  let index = self._unexpandedIndex(a:line)
  let self.expanded_indexes[index] = 1
  let self.cursor = a:line
  call self.showTitles()
endfunction

function s:Query.hideQuestion(line)
  let index = self._unexpandedIndex(a:line)
  let self.cursor = self._titleLineNumber(index)
  let self.expanded_indexes[index] = 0
  call self.showTitles()
endfunction

function s:Query._unexpandedIndex(line)
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

" returns the current title line number 
" used when the cursor might be on the description
function s:Query._titleLineNumber(index)
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

if !exists(":Vimoverflow")
  command -nargs=1 Vimoverflow :call s:SearchStackOverflow(<q-args>)
endif

if !exists(":Vo")
  command -nargs=1 Vo :call s:SearchStackOverflow(<q-args>)
endif

