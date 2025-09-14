class_name PlayerStateMachine

var player: AdventureSonic;
var states: Dictionary;
var curr_state: State;
var initial_state: String;

func _init(player: AdventureSonic):
	self.player = player
	states = {}

func add_state(state: State) -> void:
	assert(!states.has(state.get_name()))
	states[state.get_name()] = state;
	
func add_initial_state(state: State) -> void:
	add_state(state)
	initial_state = state.get_name()
	
func start_machine() -> void:
	assert(states.has(initial_state))
	for state in states:
		states[state]._ready()
	curr_state = states[initial_state]
	curr_state._begin()

	
func call_process(delta: float) -> void:
	curr_state._process(delta)
	
func call_bef_col(delta: float) -> void:
	curr_state._bef_col(delta)
	
func call_aft_col(delta: float) -> void:
	curr_state._aft_col(delta)
	
func call_bef_phys(delta: float) -> void:
	curr_state._bef_phys(delta)
	
func call_aft_phys(delta: float) -> void:
	curr_state._aft_phys(delta)
	
func transition_to(to: String) -> void:
	assert(!states.has(to))
	if(curr_state.can_transition(to)):
		curr_state._end()
		curr_state = states[to]
		curr_state._begin()

class State:
	var machine: PlayerStateMachine;
	func _init(machine: PlayerStateMachine):
		self.machine = machine
		
	func get_player() -> AdventureSonic:
		return machine.player	
		
	func get_name() -> String:
		return "No Name"
		
	func _ready() -> void:
		#print("State " + get_name() +", ready")
		return
	func _process(delta: float) -> void:
		#print("State " + get_name() +", process")
		return
	func _bef_col(delta: float) -> void:
		#print("State " + get_name() +", bef_col")
		return
	func _aft_col(delta: float) -> void:
		return
	func _bef_phys(delta: float) -> void:
		#print("State " + get_name() +", bef_phys")
		return
	func _aft_phys(delta: float) -> void:
		#print("State " + get_name() +", aft_phys")
		return
	func _begin() -> void:
		#print("State " + get_name() +", begin")
		return
	func _end() -> void:
		#print("State " + get_name() +", end")
		return
	func can_transition(next: String) -> bool:
		return true;
	
	
