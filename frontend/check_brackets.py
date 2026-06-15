import sys

def check(file_path):
    with open(file_path, 'r') as f:
        text = f.read()
    
    stack = []
    lines = text.split('\n')
    for line_num, line in enumerate(lines, 1):
        for char_num, char in enumerate(line, 1):
            if char in '([{':
                stack.append((char, line_num, char_num))
            elif char in ')]}':
                if not stack:
                    print(f"Error: unmatched {char} at line {line_num}:{char_num}")
                    return
                top_char, top_line, top_col = stack.pop()
                if (top_char == '(' and char != ')') or \
                   (top_char == '[' and char != ']') or \
                   (top_char == '{' and char != '}'):
                    print(f"Error: mismatched brackets at line {line_num}:{char_num}. Expected match for {top_char} from line {top_line}:{top_col}, got {char}")
                    return
    if stack:
        top_char, top_line, top_col = stack.pop()
        print(f"Error: unclosed {top_char} from line {top_line}:{top_col}")
    else:
        print("Brackets match!")

check('lib/features/spectator/spectator_home.dart')
