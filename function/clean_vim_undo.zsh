function clean_vim_undo() {
    emulate -L zsh
    # Let Vim evaluate computed settings instead of parsing Vimscript in the shell.
    command vim -N -n -i NONE --noplugin -es -u NONE -S /dev/stdin <<'VIM'
try
    let &undodir = ''
    execute 'source ' . fnameescape(expand('~/.vim/vimrc'))
    if empty(&undodir)
        throw 'No undodir configured in ~/.vim/vimrc'
    endif
    let directories = []
    let home = substitute(resolve(expand('~')), '/\+$', '', '')
    for directory in split(&undodir, '\\\@<!,')
        let directory = substitute(substitute(directory, '^\s*', '', ''), '\\,', ',', 'g')
        if directory !~# '^/'
            throw 'undodir must use absolute paths: ' . directory
        endif
        let directory = substitute(resolve(fnamemodify(directory, ':p')), '/\+$', '', '')
        if empty(directory) || directory ==# home
            throw 'Unsafe undodir: ' . directory
        endif
        if isdirectory(directory)
            call add(directories, directory)
        endif
    endfor
    let cutoff = localtime() - 30 * 24 * 60 * 60
    let deleted = 0
    for directory in directories
        for name in readdir(directory)
            let file = directory . '/' . name
            let modified = getftime(file)
            if getftype(file) ==# 'file' && modified >= 0 && modified < cutoff
                if delete(file) != 0
                    throw 'Cannot delete ' . file
                endif
                let deleted += 1
            endif
        endfor
    endfor
    call writefile(['Deleted ' . deleted . ' Vim undo file(s).'], '/dev/stdout', 'a')
catch
    call writefile(['clean_vim_undo: ' . v:exception], '/dev/stderr', 'a')
    cquit 1
endtry
qa!
VIM
}

function _clean_vim_undo_weekly() {
    emulate -L zsh
    [[ -o interactive ]] || return 0
    (
        [[ -r "${HOME}/.vim/vimrc" ]] || return 0
        local state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/ubuntu18_zsh_configure"
        local stamp="${state_dir}/vim-undo-cleanup"
        # Zsh's mtime qualifier checks seven days in seconds without a subprocess.
        local -a recent=("${stamp}"(Nms-604800))
        (( ${#recent} )) && return 0
        zmodload zsh/system || return 1
        umask 077
        command mkdir -p -- "${state_dir}" || return 1
        : >> "${stamp}.lock" || return 1
        local lock_fd
        zsystem flock -t 0 -f lock_fd "${stamp}.lock" 2>/dev/null || return 0
        # Another terminal may have finished cleanup before we acquired the lock.
        recent=("${stamp}"(Nms-604800))
        (( ${#recent} )) && return 0
        clean_vim_undo >/dev/null && : >| "${stamp}"
    ) &!
}
