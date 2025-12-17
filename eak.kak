# Eak / Easy Kakoune
# A set of remappings for the Kakoune editor. Requires Kakoune >= 2022.10.31.
# Author: François Tonneau

declare-option -docstring 'sentence-stop regex' \
str eak_sentence_stop [.!?]['")\]]*

declare-option -docstring 'space(s) after sentence stop' \
str eak_sentence_space <space>

# ------------------------------------------------------------
# Private variables
# ------------------------------------------------------------

declare-option -hidden str-list eak_string_list

declare-option -hidden int eak_n
declare-option -hidden str eak_reg

declare-option -hidden int eak_tally
declare-option -hidden int eak_initial

declare-option -hidden str eak_sentence_end \
"%opt(eak_sentence_stop)(%opt(eak_sentence_space)|\n)"

declare-option -hidden str eak_matching_pair \
\A\(.*\)\z|\A\{.*\}\z|\A\[.*\]\z|\A<lt>.*<gt>\z

declare-option -hidden str eak_surround_key

# ------------------------------------------------------------
# Eak modes
# ------------------------------------------------------------

declare-user-mode EakGrp    # grouping
declare-user-mode EakBeg    # beginning
declare-user-mode EakMid    # middle
declare-user-mode EakEnd    # end

define-command -hidden -params 3 eak-enter-mode %{
    # Args: 1 = mode, 2 = count, 3 = register
    enter-user-mode %arg(1)
    set-option window eak_n %arg(2)
    set-option window eak_reg %arg(3)
}

# ------------------------------------------------------------
# General utilities
# ------------------------------------------------------------

define-command -hidden -params 0 eak-check-strings nop
# see https://gitlab.com/kstr0k/sel-editor.kak/-/snippets/2178452

define-command -hidden -params 2 eak-is-same %{
    set-option window eak_string_list %arg(1)
    set-option -remove window eak_string_list %arg(2)
    eak-check-strings %opt(eak_string_list)
}

define-command -hidden -params 2 eak-is-greater %{
    set-option window eak_tally %arg(1)
    set-option -remove window eak_tally %arg(2)
    set-option -remove window eak_tally 1
    # Fail if eak_tally < 0, as '-...' looks like an illegal echo option.
    evaluate-commands -draft %{
        echo %opt(eak_tally)
    }
}

define-command -hidden eak-is-oriented-left %{
    evaluate-commands -draft %{
        eak-is-greater %val(selection_length) 1
        set-option window eak_initial %val(selection_length)
        execute-keys L
        eak-is-greater %opt(eak_initial) %val(selection_length)
    }
}

define-command -hidden eak-is-oriented-right %{
    evaluate-commands -draft %{
        try %{
            eak-is-same %val(selection_length) 1
        } \
        catch %{
            set-option window eak_initial %val(selection_length)
            execute-keys H
            eak-is-greater %opt(eak_initial) %val(selection_length)
        }
    }
}

define-command -hidden -params 1 eak-set-object-repeat %{
    map global normal o %arg(1)
}

# ------------------------------------------------------------
# Key-execution utilities
# ------------------------------------------------------------

define-command -hidden -params .. eak-type %{
    # Execute a key sequence with hooks. Eak keeps hooks active as much as
    # possible, as plugins may depend on them for working properly.
    execute-keys -with-hooks %arg{@}
}

define-command -hidden -params 1 eak-flip %{
    # Arg = requested direction, L or R
    try %{
        eak-is-same %arg(1) L
        eak-type <a-:><a-semicolon>
    } \
    catch %{
        eak-type <a-:>
    }
}

define-command -hidden -params 3 eak-flip-select %{
    # Args: 1 = direction, 2 = operation, 3 = object
    eak-flip %arg(1)
    try %{
        eak-type "<%arg(2)>" "<%arg(3)>"
        eak-set-object-repeat ":eak-flip-select %arg(@) <ret>"
    } \
    catch %{
        eak-clean
    }
}

define-command -hidden -params 3 eak-block-type %{
    # Args: 1 = count, 2 = selector, 3 = object
    # Run all steps except one, then run the last step singly to facilitate
    # selection undoing.
    try %{
        eak-is-greater %arg(1) 1
        set-option window eak_tally %arg(1)
        set-option -remove window eak_tally 1
        eak-type %opt(eak_tally) "<%arg(2)>" %arg(3)
    }
    eak-type "<%arg(2)>" %arg(3)
}

define-command -hidden -params 4 eak-nest-select %{
    # Args: 1 = direction, 2 = count, 3 = selector, 4 = object
    try %{
        eak-flip %arg(1)
        eak-block-type %arg(2) %arg(3) %arg(4)
        eak-set-object-repeat ":eak-nest-select %arg(1) 1 %arg(3) %arg(4) <ret>"
    }
}

define-command -hidden -params 1 eak-quote-select %{
    # Arg: 1 = object
    eak-type <a-i> %arg(1)
    eak-set-object-repeat <a-.>
}

define-command -hidden eak-clean %{
    # Execute <esc> with hooks. This will clear any active info box or echo
    # message, and will call hooks associated with the Escape key. The latter
    # may be used, for example, to refresh a status line that auto-updates on
    # Normal-mode key presses.
    execute-keys -with-hooks <esc>
}

# ------------------------------------------------------------
# Horizontal movement
# ------------------------------------------------------------

define-command -hidden eak-has-chars %{
    execute-keys -draft <a-k> .. <ret>
}

define-command -hidden -params 3 eak-visit-cell %{
    # Args: 1 = count, 2 = movement, 3 = extension
    try %{
        eak-has-chars
        eak-type %arg(1) %arg(3)
    } \
    catch %{
        eak-type %arg(1) %arg(2)
    }
}

define-command -hidden -params 2 eak-group-cells %{
    # Args: 1 = direction, 2 = extension
    eak-flip %arg(1)
    eak-type %opt(eak_n) %arg(2)
}

# ------------------------------------------------------------
# Vertical movement
# ------------------------------------------------------------

define-command -hidden eak-has-lines %{
    execute-keys -draft <a-k> \A ^ .*? \n .*? \n \z <ret>
}

define-command -hidden -params 3 eak-visit-line %{
    # Args: 1 = count, 2 = movement, 3 = extension
    try %{
        eak-has-lines
        eak-type %arg(1) %arg(3) x
    } \
    catch %{
        eak-type %arg(1) %arg(2)
    }
}

define-command -hidden -params 2 eak-group-lines %{
    # Args: 1 = direction, 2 = extension
    eak-flip %arg(1)
    eak-type %opt(eak_n) %arg(2) x
}

# ------------------------------------------------------------
# Word-based movement
# ------------------------------------------------------------

define-command -hidden eak-exceeds-word %{
    execute-keys -draft <a-k> \S\s+\S | \s\S+\s <ret>
}

define-command -hidden -params 3 eak-visit-word %{
    # Args: 1 = count, 2 = movement, 3 = extension
    try %{
        eak-exceeds-word
        try %{ eak-type %arg(1) "<%arg(3)>" }
    } \
    catch %{
        try %{ eak-type %arg(1) "<%arg(2)>" }
    }
    try %{
        # Refinement: trim trailing non-blank if moving backward.
        eak-is-same %arg(2) a-b
        eak-is-oriented-right
        execute-keys -draft <a-k> \s\S\z <ret>
        eak-type H
    }
}

define-command -hidden -params 2 eak-group-words %{
    # Args: 1 = direction, 2 = extension
    eak-flip %arg(1)
    try %{ eak-type %opt(eak_n) "<%arg(2)>" }
    try %{ eak-exceeds-word } catch %{
        try %{ eak-type "<%arg(2)>" }   # Retry if objective not met.
    }
}

# ------------------------------------------------------------
# Character detachment
# ------------------------------------------------------------

define-command -hidden eak-detach %{
    try %{
        execute-keys -draft <a-k>..<ret>
        eak-type <semicolon>
    } \
    catch %{
        try %{
            execute-keys -draft <a-k>\n<ret>
            eak-type jgh
        } \
        catch %{
            try %{
                execute-keys -draft <a-k>^.<ret>
                eak-type j
            } \
            catch %{
                eak-type l
            }
        }
    }
}

# ------------------------------------------------------------
# Character-based movement
# ------------------------------------------------------------

define-command -hidden -params 3 eak-find-char %{
    # Args: 1 = direction, 2 = count, 3 = search
    on-key %{
        eak-flip %arg(1)
        try %{
            eak-type %arg(2) "<%arg(3)>" %val(key)
            eak-type <semicolon>
            eak-set-object-repeat <a-.>
        } \
        catch %{
            eak-clean
        }
    }
}

# ------------------------------------------------------------
# Movement by subwords
# ------------------------------------------------------------

define-command -hidden eak-select-chunk-fd %{
    try %{
        eak-flip R
        try %{
            eak-contains-frontier
            eak-type 1 s \A .*? ([^\W_]) <ret>
        } \
        catch %{
            eak-type <?> [^\W_] <ret>
        }
        eak-type <semicolon>
        eak-grow-chunk-left
        eak-grow-chunk-right
    }
}

define-command -hidden eak-contains-frontier %{
    evaluate-commands -draft %{
        try %{ execute-keys <a-k> [^A-Z][A-Z] <ret> } \
        catch %{ execute-keys <a-k> ([^\W_][\W_])|([\W_][^\W_]) <ret> }
    }
}

define-command -hidden eak-grow-chunk-left %{
    try %{
        eak-flip R
        # If not at line start ...
        execute-keys -draft <a-K> ^\A <ret>
        eak-flip L
        # or on 2nd char of a transition,
        execute-keys -draft H <a-K> \A ([^A-Z][A-Z] | [\W_][^\W_]) <ret>
        # find transition/newline on the left, and adjust cursor.
        eak-type <a-?> ([^A-Z][A-Z] | [\W_][^\W_] | \n[^\n]) <ret> L
    }
}

define-command -hidden eak-grow-chunk-right %{
    try %{
        eak-flip R
        # If not at line end ...
        execute-keys -draft L <a-K> \n \z <ret>
        # or on 1st char of a transition,
        execute-keys -draft L <a-K> ([^A-Z][A-Z] | [^\W_][\W_]) \z <ret>
        # find transition/newline on the right, and adjust cursor.
        eak-type <?> ([^A-Z][A-Z] | [^\W_][\W_] | [^\n]\n ) <ret> H
    }
}

define-command -hidden eak-select-chunk-bd %{
    try %{
        eak-flip R
        try %{
            eak-contains-frontier
            eak-type 1 s \A .* ([^\W_]) <ret>
        } \
        catch %{
            eak-type <a-?> [^\W_] <ret>
        }
        eak-type <semicolon>
        eak-grow-chunk-left
        eak-grow-chunk-right
    }
}

define-command -hidden eak-extend-chunk-fd %{
    try %{
        eak-flip R
        eak-type <?> [^\W_] <ret>
        eak-grow-chunk-right
    }
}

# ------------------------------------------------------------
# Line selection
# ------------------------------------------------------------

define-command -hidden -params 0..1 eak-select-line-start %{
    # Args: 1 = optional trimming
    eak-flip L
    eak-type <a-H>
    try %{ eak-type %arg(1) }
    eak-set-object-repeat ":eak-select-line-start %arg(1) <ret>"
}

define-command -hidden -params 0..1 eak-select-line-end %{
    # Args: 1 = optional trimming
    eak-flip R
    eak-type <a-L>
    try %{
        execute-keys -draft <a-K> \n \z <ret>   # If not at line end,
        eak-type L                              # include it.
    }
    try %{ eak-type %arg(1) }
    eak-set-object-repeat ":eak-select-line-end %arg(1) <ret>"
}

define-command -hidden -params 0..1 eak-select-line %{
    # Args: 1 = optional trimming
    eak-type x
    try %{ eak-type %arg(1) }
    eak-set-object-repeat ":eak-select-line %arg(1) <ret>"
}

# ------------------------------------------------------------
# Sentence selection
# ------------------------------------------------------------

define-command -hidden -params 1..2 eak-select-sn-end %{
    # Args: 1 = orientation, 2 = optional finish
    try %{
        eak-is-same %arg(1) L
        try %{
            eak-flip L
            eak-type <a-?> %opt(eak_sentence_end) <ret>
            eak-flip R
            eak-type 2 s \A %opt(eak_sentence_end) \s* (.*) \z <ret>
            #     includes 1 () group --^               ^ -- () group number 2
            eak-flip L
        }
    } \
    catch %{
        eak-flip R
        try %{ eak-type <?> %opt(eak_sentence_end) <ret> }
    }
    try %{ eak-type %arg(2) }
    eak-set-object-repeat ":eak-select-sn-end %arg(@) <ret>"
}

define-command -hidden -params 0..1 eak-select-full-sn %{
    # Args: 1 = optional finish
    try %{
        eak-select-sn-end L
        eak-select-sn-end R %arg(1)
        eak-set-object-repeat ":eak-select-sn-again %arg(1) <ret>"
    }
}

define-command -hidden -params 0..1 eak-select-sn-again %{
    # Args: 1 = optional finish
    try %{
        # If on sentence end, extend to next end.
        execute-keys -draft ^ <a-k> %opt(eak_sentence_stop) \s* \z <ret>
        try %{
            eak-type <?> %opt(eak_sentence_end) <ret>
            eak-type %arg(1)
        }
    } \
    catch %{
        # Else, select full sentence.
        eak-select-full-sn %arg(1)
    }
}

# ------------------------------------------------------------
# Paragraph selection
# ------------------------------------------------------------

define-command -hidden -params 3 eak-select-pg-end %{
    # Args: 1 = orientation, 2 = count, 3 = selector
    eak-flip %arg(1)
    eak-block-type %arg(2) %arg(3) p
    eak-type x
    eak-set-object-repeat ":eak-select-pg-end %arg(1) 1 %arg(3) <ret>"
}

define-command -hidden -params 2 eak-select-full-pg %{
    # Args: 1 = count, 2 = selector
    eak-type gl # necessary when already at paragraph start
    eak-select-pg-end L 1 '{' # } please the parser
    eak-select-pg-end R %arg(1) %arg(2)
    eak-set-object-repeat ":eak-select-pg-again %arg(2) <ret>"
}

define-command -hidden -params 1 eak-select-pg-again %{
    # Args: 1 = selector
    try %{
        # If on paragraph end, extend down.
        execute-keys -draft ^ <a-k> \S+ \n\n+ \z <ret>
        eak-type "<%arg(1)>" p
    } \
    catch %{
        # Otherwise, select full paragraph if on an occupied line.
        try %{
            execute-keys -draft <semicolon> x <a-k> \S <ret>
            eak-select-full-pg 1 %arg(1)
        }
    }
}

# ------------------------------------------------------------
# Characters and delimiter object; counts are not supported.
# ------------------------------------------------------------

define-command -hidden -params 2 eak-reach-char %{
    # Args: 1 = direction, 2 = search
    on-key %{
        try %{
            eak-flip %arg(1)
            eak-type "<%arg(2)>" %val(key)
            try %{
                eak-is-same %arg(1) L
                eak-set-object-repeat H<a-.>
            } \
            catch %{
                eak-set-object-repeat L<a-.>
            }
        }
    }
}

define-command -hidden -params 1 eak-reach-lims %{
    # Arg = key
    on-key %{
        try %{
            eak-type "<%arg(1)>" %val(key)
        }
    }
}

# ------------------------------------------------------------
# Matching pairs
# ------------------------------------------------------------

define-command -hidden -params 3 eak-find-matching-pair %{
    # Args: 1 = direction, 2 = adjustment, 3 = search
    eak-flip %arg(1)
    try %{
        eak-type <a-k> %opt(eak_matching_pair) <ret>    # if on match
        eak-type %arg(2)                                # get unstuck
    }
    try %{ eak-type "<%arg(3)>" } \
    catch %{ echo 'balance missing' }
}

# ------------------------------------------------------------
# Rotation
# ------------------------------------------------------------

define-command -hidden -params 2 eak-rotate %{
    # Args: 1 = count, 2 = operation
    try %{
        eak-is-same %val(selection_count) 1
        eak-split-and-rotate %arg(1) %arg(2)
    } \
    catch %{
        eak-type %arg(1) "<%arg(2)>"
    }
}

define-command -hidden -params 2 eak-split-and-rotate %{
    # Args: 1 = count, 2 = operation
    try %{
        eak-rotate-pgs %arg(1) %arg(2)
    } \
    catch %{
        try %{
            eak-rotate-lines %arg(1) %arg(2)
        } \
        catch %{
            eak-rotate-words %arg(1) %arg(2)
        }
    }
}

define-command -hidden -params 2 eak-rotate-pgs %{
    # Args: 1 = count, 2 = operation
    execute-keys -draft <a-k> \A ^ .*\S\n\n+ .*\S\n\n+ \z <ret>
    eak-type S \n\n+ <ret> %arg(1) "<%arg(2)>"
}

define-command -hidden -params 2 eak-rotate-lines %{
    # Args: 1 = count, 2 = operation
    try %{
        # one empty line + one full line?
        execute-keys -draft <a-k> \A ^\n [^\n]+\n \z <ret>
        eak-type <a-:><a-semicolon><semicolon> <a-d> <a-o>
    } \
    catch %{
        try %{
            # one full line + one empty line?
            execute-keys -draft <a-k> \A ^[^\n]+\n \n \z <ret>
            eak-type <a-:><semicolon> <a-d> k <a-O>
        } \
        catch %{
            # full lines?
            execute-keys -draft <a-k> \A ^ .+\n .+\n \z <ret>
            eak-type S \n <ret> %arg(1) "<%arg(2)>"
        }
    }
}

define-command -hidden -params 2 eak-rotate-words %{
    # Args: 1 = count, 2 = operation
    try %{
        execute-keys -draft <a-k> \A \w+ [\W_-]+ \w+ \s* \z <ret>
        eak-type S [\W_-]+ <ret> %arg(1) "<%arg(2)>"
    }
}

# ------------------------------------------------------------
# Yanking and pasting
# ------------------------------------------------------------

define-command -hidden -params 1 eak-paste-all %{
    # Arg = unbracketed key for pasting, a-P or a-p
    try %{
        eak-type <"> %opt(eak_reg) "<%arg(1)>"
    }
}

define-command -hidden eak-replace-with-all %{
    try %{
        eak-type <"> %opt(eak_reg) <a-R>
    }
}

# ------------------------------------------------------------
# Selection adjustment
# ------------------------------------------------------------

define-command -hidden eak-widen %{
    try %{
        eak-is-oriented-left
        eak-type H <a-:>L <a-semicolon>
    } \
    catch %{
        eak-type L <a-semicolon>H <a-:>
    }
}

define-command -hidden eak-shrink %{
    try %{
        eak-type 1s \A . (.+) . \z <ret>
    }
}

define-command -hidden -params 1 eak-adjust-tail %{
    # Arg = adjusment key
    eak-type <a-semicolon> %arg(1) <a-semicolon>
}

# ------------------------------------------------------------
# Marks
# ------------------------------------------------------------

define-command -hidden eak-mark %{
    info 'Mark place with <letter>:'
    on-key %{
        try %{
            eak-type <"> %val(key) Z <semicolon>
            echo "Marked as %val(key)"
        } \
        catch eak-clean
    }
}

define-command -hidden eak-goto-mark %{
    info 'Go to mark <letter>:'
    on-key %{
        try %{
            eak-type <"> %val(key) z v c
            echo "Back to %val(key)"
        } \
        catch eak-clean
    }
}

define-command -hidden eak-init-marks %{
    eak-type -save-regs %{} <"> %opt(eak_reg) Z
    echo 'Marks started'
}

define-command -hidden eak-add-to-marks %{
    try %{
        eak-type -save-regs %{} <"> %opt(eak_reg) <a-Z> a
        # If there are previous marks, <a-Z> opens a mark menu and <a> adds the
        # selection to the marks. If there are no previous marks, however, <a-Z>
        # bypasses the menu and <a> activates Insert mode. So,
        eak-type <esc>     # back to Normal mode in any case.
        echo 'Mark added'
    } \
    catch %{ echo 'Cannot add selection' }
}

define-command -hidden eak-view-marks %{
    try %{
        eak-type -save-regs %{} <"> %opt(eak_reg) z
    } \
    catch %{ echo 'Cannot view marks' }
}

define-command -hidden eak-mix-with-marks %{
    try %{
        eak-type -save-regs %{} <"> %opt(eak_reg) <a-Z>
    } \
    catch %{ echo 'Operation forbidden' }
}

define-command -hidden eak-mix-with-selection %{
    try %{
        eak-type -save-regs %{} <"> %opt(eak_reg) <a-z>
    } \
    catch %{ echo 'Operation forbidden' }
}

define-command -hidden -params 1 eak-transfer-contents %{
    # Arg = key
    try %{
        evaluate-commands -draft %{
            execute-keys -save-regs %{} <"> %opt(eak_reg) z
            execute-keys -save-regs %{} %arg(1)     # delete or yank
        }
        eak-type -save-regs %{} <a-P>              # paste
    } \
    catch %{ echo 'Transfer failed' }
}

define-command -hidden eak-transpose-content %{
    try %{
        eak-type -save-regs %{} <"> %opt(eak_reg) <a-z> a <a-(> ) ,
    } \
    catch %{ echo 'Exchange failed' }
}

# ------------------------------------------------------------
# Paragraph and sentence navigation
# ------------------------------------------------------------

define-command -hidden -params 1 eak-jump-pg-up %{
    # Args: 1 = count
    eak-flip L
    try %{
        eak-type <a-b>         # avoid getting stuck on the left
        eak-type %arg(1) <a-?> \n\n+ <ret>
        eak-type 1 s \A (\n+) <ret>
        eak-type <a-:> l
    } \
    catch %{ eak-type gg }
}

define-command -hidden -params 1 eak-jump-pg-down %{
    # Args: 1 = count
    eak-flip R
    try %{
        eak-type %arg(1) ? \n\n+ <ret>
        eak-type l
    } \
    catch %{ eak-type ge }
}

define-command -hidden eak-jump-sn-up %{
    evaluate-commands -save-regs a %{
        execute-keys %{"} a Z           # save position
        eak-flip L
        try %{
            eak-type <a-?> \S <ret>     # avoid getting stuck on the left
            eak-type <a-?> %opt(eak_sentence_end) <ret>
            eak-type <semicolon> <?> \s+\S <ret>
            eak-type <semicolon>
        } \
        catch %{
            execute-keys %{"} a z       # if nothing found, restore position
            eak-clean                   # hide restoration message
        }
    }
}

define-command -hidden eak-jump-sn-down %{
    eak-flip R
    try %{
        eak-type <?> %opt(eak_sentence_end) <ret>
        eak-type <?> \S <ret>
    }
    eak-type <semicolon>
}

# ------------------------------------------------------------
# Goto commands
# ------------------------------------------------------------

define-command -hidden eak-goto-midline %{
    eak-type gl
    evaluate-commands %sh{
        lastcol=$kak_cursor_char_column
        if [ $lastcol -gt 2 ]; then
            printf %s "eak-type gh $((lastcol / 2)) l"
        else
            printf %s eak-clean
        fi
    }
}

define-command -hidden eak-leave-up %{
    eak-type 1 <,>
    eak-flip L
    eak-type ghk
}

define-command -hidden eak-leave-down %{
    eak-type %val(selection_count) <,>
    eak-flip R
    eak-type ghj
}

define-command -hidden eak-leave-by-pg-up %{
    eak-leave-up
    eak-jump-pg-up 1
}

define-command -hidden eak-leave-by-pg-down %{
    eak-leave-down
    eak-jump-pg-down 1
}

# ------------------------------------------------------------
# Search
# ------------------------------------------------------------

define-command -hidden -params 1 eak-search-fd %{
    # Arg = count
    eak-type %arg(1) /
    map window normal n n
    map window normal <a-n> N
    map window normal N <a-n>
}

define-command -hidden -params 1 eak-search-bd %{
    # Arg = count
    eak-type %arg(1) <a-/>
    map window normal n <a-n>
    map window normal <a-n> <a-N>
    map window normal N n
}

define-command -hidden eak-truncate-search %{
    try %{
        eak-is-oriented-left
        try %{ eak-type 1 s <c-p> <c-a> \A <c-e> (.*) \z <ret> }
    } \
    catch %{
        try %{ eak-type 1 s <c-p> <c-a> \A (.*) <c-e> \z <ret> }
    }
}

# ------------------------------------------------------------
# Tab/space conversion
# ------------------------------------------------------------

define-command -hidden eak-convert-space %{
    info 's: tabs to spaces, t: spaces to tabs'
    on-key %{
        evaluate-commands %sh{
            case $kak_key in
                s) printf %s 'eak-type <@>' ;;
                t) printf %s 'eak-type <a-@>' ;;
                *) printf eak-clean ;;
            esac
        }
    }
}

# ------------------------------------------------------------
# Surrounding
# ------------------------------------------------------------

define-command -hidden eak-surround %{
    info 'Type surrounding character, or (c) to change, (d) to delete:'
    on-key %{
        set-option window eak_surround_key %val(key)
        evaluate-commands %sh{
            case $kak_key in
                c) printf eak-change-surround ;;
                d) printf eak-delete-surround ;;
                *) printf 'eak-touch-surround ADD' ;;
            esac
        }
    }
}

define-command -hidden eak-change-surround %{
    info 'Type character:'
    on-key %{
        set-option window eak_surround_key %val(key)
        eak-touch-surround CHANGE
    }
}

define-command -hidden eak-delete-surround %{
    evaluate-commands -save-regs c %{
        eak-flip R
        try %{
            execute-keys <a-k> ... <ret>
            execute-keys -draft 1s \A.(.+).\z <ret> <">c Z  # save (center) to c
            eak-type <a-S> <a-d>
            eak-type <">c z                                 # restore
        }
        eak-clean
    }
}

define-command -hidden -params 1 eak-touch-surround %‖
    # Arg = ADD or CHANGE
    try %§
        evaluate-commands %sh@
            key=$kak_opt_eak_surround_key
            case $key in
                '<c-'* | '<a-'* | '<F'* ) exit ;;
                '<up>' | '<down>' | '<left>' | '<right>' ) exit ;;
                '<pageup>' | '<pagedown>' | '<home>' | '<end>' ) exit ;;
                '<backspace>' | '<del>' | '<esc>' | '<ret>' ) exit ;;
                '<ins>' | '<tab>' ) exit ;;
                '<gt>') key='>' ;;
                '<lt>') key='<' ;;
                '<minus>') key='-' ;;
                '<plus>') key='+' ;;
                '<percent>') key='%' ;;
                '<quote>') key="'" ;;
                '<dquote>') key='"' ;;
                '<semicolon>') key=';' ;;
                '<space>') key=' ' ;;
            esac
            case $key in
                "'")
                    left="%{'}"
                    right="%{'}"
                    ;;
                *)
                    left="'$key'"
                    right=$(printf %s "$left" | tr '{}()[]<>' '}{)(][><')
                    ;;
            esac
            case $1 in
                ADD) printf %s\\n 'eak-flip R' ;;
                CHANGE) printf %s\\n eak-delete-surround ;;
            esac
            printf %s\\n "exec i $left <esc> a $right <esc>"
            printf %s\\n "exec <a-semicolon> H <a-:>"
        @
    §
    eak-clean
‖

# ------------------------------------------------------------
# Command to apply all mappings; will be called below, but can also be called
# on purpose to restore Eak's mappings.
# ------------------------------------------------------------

define-command -docstring 'eak-map: run eak mappings' eak-map %§

map global normal <minus> ':eak-enter-mode EakGrp %val(count) %val(register) <ret>'
map global normal z       ':eak-enter-mode EakBeg %val(count) %val(register) <ret>'
map global normal x       ':eak-enter-mode EakMid %val(count) %val(register) <ret>'
map global normal e       ':eak-enter-mode EakEnd %val(count) %val(register) <ret>'

map global normal h ':eak-visit-cell %val(count) h H <ret>'
map global normal l ':eak-visit-cell %val(count) l L <ret>'
map global EakGrp h ':eak-group-cells L H <ret>' -docstring '+ cell right'
map global EakGrp l ':eak-group-cells R L <ret>' -docstring '+ cell left'

map global normal j ':eak-visit-line %val(count) j J <ret>'
map global normal k ':eak-visit-line %val(count) k K <ret>'
map global EakGrp j ':eak-group-lines R J <ret>' -docstring '+ line down'
map global EakGrp k ':eak-group-lines L K <ret>' -docstring '+ line up'

map global normal b ':eak-visit-word %val(count) a-b a-B <ret>'
map global normal w ':eak-visit-word %val(count) a-w a-W <ret>'
map global EakGrp b ':eak-group-words L a-B <ret>' -docstring '+ word left'
map global EakGrp w ':eak-group-words R a-W <ret>' -docstring '+ word right'

map global normal , ':eak-detach <ret>'

map global normal o <a-.>

map global normal t     ':eak-find-char R %val(count) F <ret>'
map global normal <a-t> ':eak-find-char L %val(count) a-F <ret>'

map global normal f     ':eak-select-chunk-fd <ret>'
map global normal E     ':eak-extend-chunk-fd <ret>'
map global normal <a-f> ':eak-select-chunk-bd <ret>'

map global EakBeg i I      -docstring '|< insert'
map global EakBeg <lt> <!> -docstring 'output<'
map global EakBeg <ret>   ':eak-flip-select L   { space <ret><a-x>'    -docstring Space
map global EakBeg <space> ':eak-flip-select L a-{ space <ret>'         -docstring space
map global EakBeg W       ':eak-flip-select L a-{ a-w <ret>'           -docstring Word
map global EakBeg w       ':eak-flip-select L a-{   w <ret>'           -docstring word
map global EakBeg l       ':eak-select-line-start   <ret>'             -docstring Line
map global EakBeg x       ':eak-select-line-start _ <ret>'             -docstring >line<
map global EakBeg s       ':eak-select-sn-end L <ret>'                 -docstring Sentence
map global EakBeg e       ':eak-select-sn-end L <ret>'                 -docstring sentence
map global EakBeg p       ':eak-select-pg-end L %opt(eak_n)   { <ret>' -docstring Paragraph
map global EakBeg h       ':eak-select-pg-end L %opt(eak_n) a-{ <ret>' -docstring paragraph
map global EakBeg n       ':eak-flip-select L   { n <ret>'             -docstring Number
map global EakBeg r       ':eak-flip-select L a-{ n <ret>'             -docstring number
map global EakBeg <_>     ':eak-flip-select L   { i <ret>'             -docstring Indent
map global EakBeg <minus> ':eak-flip-select L a-{ i <ret>'             -docstring indent
map global EakBeg A       ':eak-nest-select L %opt(eak_n)   { a <ret>' -docstring Angles
map global EakBeg a       ':eak-nest-select L %opt(eak_n) a-{ a <ret>' -docstring angles
map global EakBeg B       ':eak-nest-select L %opt(eak_n)   { { <ret>' -docstring Braces
map global EakBeg b       ':eak-nest-select L %opt(eak_n) a-{ { <ret>' -docstring braces
map global EakBeg K       ':eak-nest-select L %opt(eak_n)   { [ <ret>' -docstring Brackets
map global EakBeg k       ':eak-nest-select L %opt(eak_n) a-{ [ <ret>' -docstring brackets
map global EakBeg C       ':eak-nest-select L %opt(eak_n)   { ( <ret>' -docstring Parentheses
map global EakBeg c       ':eak-nest-select L %opt(eak_n) a-{ ( <ret>' -docstring parentheses
map global EakBeg U       ':eak-flip-select L   { u <ret>'             -docstring Argument
map global EakBeg u       ':eak-flip-select L a-{ u <ret>'             -docstring argument
map global EakBeg %{"}    ':eak-flip-select L a-{ Q <ret>'             -docstring 2-quotes
map global EakBeg %{'}    ':eak-flip-select L a-{ q <ret>'             -docstring 1-quotes
map global EakBeg %{`}    ':eak-flip-select L a-{ g <ret>'             -docstring backticks
map global EakBeg y x<a-:><a-semicolon>Gg         -docstring Buffer
map global EakBeg t ':eak-reach-char L a-T <ret>' -docstring character
map global EakBeg m ':eak-flip L <ret><a-M>'      -docstring [match]
map global EakBeg / <a-:><a-semicolon><a-?>       -docstring search

map global EakMid <ret>   ':eak-flip-select R a-a space <ret><a-x>'    -docstring Space
map global EakMid <space> ':eak-flip-select R a-i space <ret>'         -docstring space
map global EakMid W       ':eak-flip-select R a-i a-w <ret>'           -docstring Word
map global EakMid w       ':eak-flip-select R a-i   w <ret>'           -docstring word
map global EakMid l       ':eak-select-line   <ret>'                   -docstring Line
map global EakMid x       ':eak-select-line _ <ret>'                   -docstring >line<
map global EakMid s       ':eak-select-full-sn   <ret>'                -docstring Sentence
map global EakMid e       ':eak-select-full-sn _ <ret>'                -docstring sentence
map global EakMid p       ':eak-select-full-pg %opt(eak_n) }   <ret>'  -docstring Paragraph
map global EakMid h       ':eak-select-full-pg %opt(eak_n) a-} <ret>'  -docstring paragraph
map global EakMid n       ':eak-flip-select R a-a n <ret>'             -docstring Number
map global EakMid r       ':eak-flip-select R a-i n <ret>'             -docstring number
map global EakMid <_>     ':eak-flip-select R a-a i <ret>'             -docstring Indent
map global EakMid <minus> ':eak-flip-select R a-i i <ret>'             -docstring indent
map global EakMid A       ':eak-nest-select R %opt(eak_n) a-a a <ret>' -docstring Angles
map global EakMid a       ':eak-nest-select R %opt(eak_n) a-i a <ret>' -docstring angles
map global EakMid B       ':eak-nest-select R %opt(eak_n) a-a { <ret>' -docstring Braces
map global EakMid b       ':eak-nest-select R %opt(eak_n) a-i { <ret>' -docstring braces
map global EakMid K       ':eak-nest-select R %opt(eak_n) a-a [ <ret>' -docstring Brackets
map global EakMid k       ':eak-nest-select R %opt(eak_n) a-i [ <ret>' -docstring brackets
map global EakMid C       ':eak-nest-select R %opt(eak_n) a-a ( <ret>' -docstring Parentheses
map global EakMid c       ':eak-nest-select R %opt(eak_n) a-i ( <ret>' -docstring parentheses
map global EakMid U       ':eak-flip-select R a-a u <ret>'             -docstring Argument
map global EakMid u       ':eak-flip-select R a-i u <ret>'             -docstring argument
map global EakMid %{"}    ':eak-quote-select Q <ret>'                  -docstring 2-quotes
map global EakMid %{'}    ':eak-quote-select q <ret>'                  -docstring 1-quotes
map global EakMid %{`}    ':eak-quote-select g <ret>'                  -docstring backticks
map global EakMid y <percent>                   -docstring Buffer
map global EakMid R <a-a>c                      -docstring <RE,RE>
map global EakMid E <a-i>c                      -docstring RE>,<RE
map global EakMid t ':eak-reach-lims a-i <ret>' -docstring delimiter
map global EakMid * <a-*>                       -docstring 'exact search'

map global EakEnd i A        -docstring 'insert >|'
map global EakEnd <gt> <a-!> -docstring '>output'
map global EakEnd <ret>   ':eak-flip-select R   } space <ret><a-x>'    -docstring Space
map global EakEnd <space> ':eak-flip-select R a-} space <ret>'         -docstring space
map global EakEnd W       ':eak-flip-select R a-} a-w <ret>'           -docstring Word
map global EakEnd w       ':eak-flip-select R a-}   w <ret>'           -docstring word
map global EakEnd l       ':eak-select-line-end   <ret>'               -docstring Line
map global EakEnd x       ':eak-select-line-end _ <ret>'               -docstring >line<
map global EakEnd s       ':eak-select-sn-end R   <ret>'               -docstring Sentence
map global EakEnd e       ':eak-select-sn-end R _ <ret>'               -docstring sentence
map global EakEnd p       ':eak-select-pg-end R %opt(eak_n)   } <ret>' -docstring Paragraph
map global EakEnd h       ':eak-select-pg-end R %opt(eak_n) a-} <ret>' -docstring paragraph
map global EakEnd n       ':eak-flip-select R   } n <ret>'             -docstring Number
map global EakEnd r       ':eak-flip-select R a-} n <ret>'             -docstring number
map global EakEnd <_>     ':eak-flip-select R   } i <ret>'             -docstring Indent
map global EakEnd <minus> ':eak-flip-select R a-} i <ret>'             -docstring indent
map global EakEnd A       ':eak-nest-select R %opt(eak_n)   } a <ret>' -docstring Angles
map global EakEnd a       ':eak-nest-select R %opt(eak_n) a-} a <ret>' -docstring angles
map global EakEnd B       ':eak-nest-select R %opt(eak_n)   } } <ret>' -docstring Braces
map global EakEnd b       ':eak-nest-select R %opt(eak_n) a-} } <ret>' -docstring braces
map global EakEnd K       ':eak-nest-select R %opt(eak_n)   } ] <ret>' -docstring Brackets
map global EakEnd k       ':eak-nest-select R %opt(eak_n) a-} ] <ret>' -docstring brackets
map global EakEnd C       ':eak-nest-select R %opt(eak_n)   } ) <ret>' -docstring Parentheses
map global EakEnd c       ':eak-nest-select R %opt(eak_n) a-} ) <ret>' -docstring parentheses
map global EakEnd U       ':eak-flip-select R }   u <ret>'             -docstring Argument
map global EakEnd u       ':eak-flip-select R a-} u <ret>'             -docstring argument
map global EakEnd %{"}    ':eak-flip-select R a-} Q <ret>'             -docstring 2-quotes
map global EakEnd %{'}    ':eak-flip-select R a-} q <ret>'             -docstring 1-quotes
map global EakEnd %{`}    ':eak-flip-select R a-} g <ret>'             -docstring backticks
map global EakEnd y x<a-:>Ge                    -docstring Buffer
map global EakEnd t ':eak-reach-char R T <ret>' -docstring character
map global EakEnd m ':eak-flip R <ret>M'        -docstring [match]
map global EakEnd / <a-:><?>                    -docstring search

map global normal %{'} q                        # play macro

map global normal %{#} <a-,>                    # remove main
map global normal K <a-k>                       # keep matches
map global normal D <a-K>                       # discard non-matches
map global normal M <a-_>                       # merge selections
map global normal F <a-plus>                    # fuse overlap
map global normal B <a-C>                       # copy before
map global normal I <a-&>                       # copy indent
map global normal H <a-lt>                      # liberal indent <
map global normal L <a-gt>                      # liberal indent >
map global normal J <a-j>                       # join lines
map global normal W <a-J>                       # whitespace on join
map global normal T <a-x>                       # trim partial lines
map global normal Y <a-S>                       # select left+right
map global normal q ,                           # quit on main

map global EakGrp <minus> <a-s>                 -docstring '⇒ get lines'

map global normal m     ':eak-find-matching-pair R l m <ret>'
map global normal <a-m> ':eak-find-matching-pair L h a-m <ret>'

map global normal <a-q> ': eak-rotate %val(count) a-( <ret>'
map global normal <a-r> ': eak-rotate %val(count) a-) <ret>'

map global normal A     O                       # edit line above
map global normal <a-a> <a-O>                   # add line above
map global normal O     o                       # edit line below

map global normal y y<semicolon>
map global normal <a-p> P
map global EakGrp  <a-p> ':eak-paste-all a-P <ret>'     -docstring 'paste all <'
map global EakGrp p      ':eak-paste-all a-p <ret>'     -docstring 'paste all >'
map global EakGrp r      ':eak-replace-with-all <ret>'  -docstring 'replace /all'

map global normal P         ':eak-widen <ret>'
map global normal <a-minus> ':eak-shrink <ret>'
map global normal <a-h> ':eak-adjust-tail H <ret>'
map global normal <a-l> ':eak-adjust-tail L <ret>'
map global normal <a-z> i<space><esc>           # add left space
map global normal <a-e> a<space><esc>H          # add right space
map global normal <a-s> <a-semicolon>           # switch orientation

map global normal <a-x> ':eak-mark <ret>'
map global normal <a-g> ':eak-goto-mark <ret>'
map global EakGrp i ':eak-init-marks <ret>'             -docstring 'init group'
map global EakGrp a ':eak-add-to-marks <ret>'           -docstring 'add to group'
map global EakGrp c ':eak-mix-with-marks <ret>'         -docstring 'combine ⇒ group'
map global EakGrp s ':eak-mix-with-selection <ret>'     -docstring 'combine ⇒ sel'
map global EakGrp m ':eak-transfer-contents d <ret>'    -docstring 'move group here'
map global EakGrp y ':eak-transfer-contents y <ret>'    -docstring 'copy group here'
map global EakGrp t ':eak-transpose-content <ret>'      -docstring 'transpose /sel'
map global EakGrp v ':eak-view-marks <ret>'             -docstring 'view group'

map global normal [ ':eak-jump-pg-up %val(count) <ret>'
map global normal ] ':eak-jump-pg-down %val(count) <ret>'
map global normal { ':eak-jump-sn-up <ret>'
map global normal } ':eak-jump-sn-down <ret>'

map global goto . <esc>g.                               -docstring 'last change'
map global goto h <esc>gh                               -docstring 'first column'
map global goto m '<esc>:eak-goto-midline <ret>'        -docstring 'middle column'
map global goto l <esc>gl                               -docstring 'last column'
map global goto , <esc><a-:><a-semicolon><semicolon>    -docstring 'select 1st char'
map global goto k '<esc>:eak-leave-up <ret>'            -docstring 'leave up'
map global goto j '<esc>:eak-leave-down <ret>'          -docstring 'leave down'
map global goto [ '<esc>:eak-leave-by-pg-up <ret>'      -docstring 'leave up (⁋)'
map global goto ] '<esc>:eak-leave-by-pg-down <ret>'    -docstring 'leave down (⁋)'
map global goto f <esc>gf                               -docstring '> [file]'

map global normal / ':eak-search-fd %val(count) <ret>'
map global normal ? ':eak-search-bd %val(count) <ret>'
map global normal X ':eak-truncate-search <ret>'
map global normal <percent> *%s<ret>

map global normal ! <a-|>
map global normal <a-v> <a-U>                           # cf. Kakoune >= 2023.07.29
map global normal @ ':eak-convert-space <ret>'

map global normal <a-y> ':eak-surround <ret>'

§ # <= eak-map command end

eak-map

