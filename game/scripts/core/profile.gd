extends Node
## The player's lasting progress across runs (autoload "Profile"). For now
## only the Ash currency, kept in memory: saving comes with Milestone 4, server
## validation with Milestone 5. Every reward goes through grant_run_reward(),
## which accepts each run once, so a replayed signal, a double tap or a
## retried request can never pay twice. That is the seam persistence and the
## backend hook into.

signal changed

var ash: int = 0

## Runs already paid, by run id.
var _claimed: Dictionary[String, int] = {}


## Adds `amount` Ash for run `run_id` and returns true, unless that run was
## already paid (then nothing changes and it returns false).
func grant_run_reward(run_id: String, amount: int) -> bool:
	if run_id == "" or _claimed.has(run_id):
		return false
	_claimed[run_id] = maxi(amount, 0)
	ash += maxi(amount, 0)
	changed.emit()
	return true


func has_claimed(run_id: String) -> bool:
	return _claimed.has(run_id)
