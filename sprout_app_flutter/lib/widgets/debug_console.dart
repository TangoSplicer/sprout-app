import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebugConsole extends StatefulWidget {
  final List<String> logs;
  final List<String> errors;
  final String? aiFeedback;
  final VoidCallback? onClear;
  final Function(String)? onCommand;

  const DebugConsole({
    super.key,
    required this.logs,
    required this.errors,
    this.aiFeedback,
    this.onClear,
    this.onCommand,
  });

  @override
  State<DebugConsole> createState() => _DebugConsoleState();
}

class _DebugConsoleState extends State<DebugConsole> with TickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _logsScrollController = ScrollController();
  final ScrollController _errorsScrollController = ScrollController();
  final TextEditingController _commandController = TextEditingController();
  final List<String> _commandHistory = [];
  int _historyIndex = -1;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Auto-scroll to bottom when new logs arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void didUpdateWidget(DebugConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Auto-scroll when new content is added
    if (_autoScroll && (
        widget.logs.length != oldWidget.logs.length ||
        widget.errors.length != oldWidget.errors.length)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _logsScrollController.dispose();
    _errorsScrollController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_logsScrollController.hasClients) {
      _logsScrollController.animateTo(
        _logsScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    if (_errorsScrollController.hasClients) {
      _errorsScrollController.animateTo(
        _errorsScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _executeCommand(String command) {
    if (command.trim().isEmpty) return;
    
    _commandHistory.add(command);
    _historyIndex = -1;
    _commandController.clear();
    
    widget.onCommand?.call(command);
  }

  void _navigateHistory(bool up) {
    if (_commandHistory.isEmpty) return;
    
    if (up) {
      if (_historyIndex < _commandHistory.length - 1) {
        _historyIndex++;
      }
    } else {
      if (_historyIndex > 0) {
        _historyIndex--;
      } else {
        _historyIndex = -1;
        _commandController.clear();
        return;
      }
    }
    
    if (_historyIndex >= 0) {
      _commandController.text = _commandHistory[_commandHistory.length - 1 - _historyIndex];
      _commandController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commandController.text.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        border: Border.all(color: Colors.grey.shade600),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLogsTab(),
                _buildErrorsTab(),
                _buildCommandTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF4A9D5E),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade400,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.article, size: 16),
                      const SizedBox(width: 4),
                      Text('Logs (${widget.logs.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error,
                        size: 16,
                        color: widget.errors.isNotEmpty ? Colors.red : null,
                      ),
                      const SizedBox(width: 4),
                      Text('Errors (${widget.errors.length})'),
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.terminal, size: 16),
                      SizedBox(width: 4),
                      Text('Console'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_top,
                  color: Colors.grey.shade400,
                  size: 18,
                ),
                onPressed: () {
                  setState(() {
                    _autoScroll = !_autoScroll;
                  });
                  if (_autoScroll) {
                    _scrollToBottom();
                  }
                },
                tooltip: _autoScroll ? 'Disable auto-scroll' : 'Enable auto-scroll',
              ),
              IconButton(
                icon: Icon(
                  Icons.clear,
                  color: Colors.grey.shade400,
                  size: 18,
                ),
                onPressed: widget.onClear,
                tooltip: 'Clear console',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    if (widget.logs.isEmpty) {
      return const Center(
        child: Text(
          'No logs yet',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      controller: _logsScrollController,
      padding: const EdgeInsets.all(8),
      itemCount: widget.logs.length,
      itemBuilder: (context, index) {
        final log = widget.logs[index];
        return _buildLogEntry(log, LogLevel.info);
      },
    );
  }

  Widget _buildErrorsTab() {
    if (widget.errors.isEmpty) {
      return const Center(
        child: Text(
          'No errors - great job! 🎉',
          style: TextStyle(color: Colors.green),
        ),
      );
    }

    return ListView.builder(
      controller: _errorsScrollController,
      padding: const EdgeInsets.all(8),
      itemCount: widget.errors.length,
      itemBuilder: (context, index) {
        final error = widget.errors[index];
        return _buildLogEntry(error, LogLevel.error);
      },
    );
  }

  Widget _buildCommandTab() {
    return Column(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.aiFeedback != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A9D5E).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF4A9D5E)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.smart_toy,
                          color: Color(0xFF4A9D5E),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.aiFeedback!,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'Available Commands:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ..._getAvailableCommands().map(_buildCommandHelp),
              ],
            ),
          ),
        ),
        _buildCommandInput(),
      ],
    );
  }

  Widget _buildLogEntry(String message, LogLevel level) {
    final timestamp = DateTime.now().toString().split(' ')[1].substring(0, 8);
    
    Color color;
    IconData icon;
    
    switch (level) {
      case LogLevel.info:
        color = Colors.blue;
        icon = Icons.info_outline;
        break;
      case LogLevel.warning:
        color = Colors.orange;
        icon = Icons.warning_outlined;
        break;
      case LogLevel.error:
        color = Colors.red;
        icon = Icons.error_outline;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timestamp,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontFamily: 'JetBrainsMono',
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: message));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Log copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.grey.shade200,
                  fontSize: 12,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandHelp(CommandHelp help) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            help.command,
            style: const TextStyle(
              color: Color(0xFF4A9D5E),
              fontFamily: 'JetBrainsMono',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              help.description,
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        border: Border(top: BorderSide(color: Colors.grey.shade700)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.chevron_right,
            color: Color(0xFF4A9D5E),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _commandController,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'JetBrainsMono',
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: 'Type a command...',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: _executeCommand,
              onChanged: (text) {
                // Reset history navigation when typing
                if (_historyIndex >= 0) {
                  _historyIndex = -1;
                }
              },
              onTap: () {
                // Reset history navigation when tapping
                _historyIndex = -1;
              },
              textInputAction: TextInputAction.send,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.send,
              color: Color(0xFF4A9D5E),
              size: 18,
            ),
            onPressed: () => _executeCommand(_commandController.text),
          ),
        ],
      ),
    );
  }

  List<CommandHelp> _getAvailableCommands() {
    return [
      CommandHelp('clear', 'Clear all logs and errors'),
      CommandHelp('compile', 'Compile current project'),
      CommandHelp('info', 'Show project information'),
      CommandHelp('security', 'Run security analysis'),
      CommandHelp('help', 'Show this help message'),
    ];
  }
}

enum LogLevel { info, warning, error }

class CommandHelp {
  final String command;
  final String description;
  
  CommandHelp(this.command, this.description);
}

