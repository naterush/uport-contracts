pragma solidity 0.4.8;
import "../controllers/StandardController.sol";

//Now with 50% less loops!
contract RecoveryQuorumBasic {
  StandardController public controller;

  mapping (address => Delegate) public delegates;
  struct Delegate{
    uint deletedAfter; // delegate exists if not 0
    uint pendingUntil;
    address proposedUserKey;
  }


  uint[] timeDelegateNumChanges;
  mapping (uint => uint) numDelegatesAfter;
  mapping (address => uint) numVotesForKey;


  modifier currentDelegate(Delegate d) {
    if (!delegateRecordExists(d)) throw;
    if (!delegateIsCurrent(d)) {delete delegates[addressToCheck];}
    else {_;}
  }

  function RecoveryQuorumBasic(address[] _delegates, address _controller){
    controller = StandardController(_controller);

    for(uint i = 0; i < _delegates.length; i++){
      delegates[_delegates[i]] = Delegate({proposedUserKey: 0x0, pendingUntil: 0, deletedAfter: 31536000000000});
    }
    timeDelegateNumChanges.push(now); //update "piece-wise function"
    timeDelegateNumChanges.push(31536000000000);
    numDelegatesAfter[now] = _delegates.length;
  }


  function signUserKey(address proposedUserKey) currentDelegate(delegates[msg.sender]) {
    if (delegates[msg.sender].proposedUserKey == 0x0) {
      delegates[msg.sender].proposedUserKey = proposedUserKey;
      numVotesForKey[proposedUserKey] += 1;
    } else {
      numVotesForKey[delegates[msg.sender].proposedUserKey] -= 1;
      delegates[msg.sender].proposedUserKey = proposedUserKey;
      numVotesForKey[proposedUserKey] += 1;
    }
  }

  function changeUserKey(address newUserKey) {
    if(numVotesForKey[newUserKey] >= neededSignatures()){
      controller.changeUserKeyFromRecovery(newUserKey);
    }
  }

  function neededSignatures() returns (uint) {
    uint curr = 0;
    for (uint i = 0; i < timeDelegateNumChanges - 1; i++) {
      if (timeDelegateNumChanges[i + 1] <= now) {curr = i;}
    }
    return numDelegatesAfter[timeDelegateNumChanges[curr]];
  }

  function replaceDelegates(address[] delegatesToRemove, address[] delegatesToAdd) {
    uint deletedAtLongLock;
    uint addedAtLongLock;

    for(uint i = 0 ; i < delegatesToAdd.length ; i++) {
      if (!delegateRecordExists[delegates[delegatesToAdd[i]]]) {
        delegates[delegatesToAdd[i]] = Delegate({proposedUserKey: 0x0, pendingUntil: 0, deletedAfter: 31536000000000});
        addedAtLongLock++;
      }
    }

    for(uint i = 0 ; i < delegatesToRemove.length ; i++) {
      if (delegateIsDeleted[delegates[delegatesToRemove[i]]]) {
        delete delegates[delegatesToRemove[i]];
      }
      else if (delegateIsCurrent[delegates[delegatesToRemove[i]]]) {
        delegatesToRemove[i].deletedAfter = now + controller.longTimeLock();
        deletedAtLongLock++;
      } //don't account for case when delegate is pending - as it complicates things.
    }

    delInPrevEra = timeDelegateNumChanges[timeDelegateNumChanges.length - 1];
    timeDelegateNumChanges[timeDelegateNumChanges.length - 1] = now + controller.longTimeLock();
    timeDelegateNumChanges.push(31536000000000);
    numDelegatesAfter[now + controller.longTimeLock()] = delInPrevEra + addedAtLongLock - deletedAtLongLock;
  }

  function delegateRecordExists(Delegate d) private returns (bool){
      return d.deletedAfter != 0;
  }
  function delegateIsDeleted(Delegate d) private returns (bool){
      return d.deletedAfter <= now;
  }
  function delegateIsCurrent(Delegate d) private returns (bool){
      return delegateRecordExists(d) && !delegateIsDeleted(d) && now > d.pendingUntil;
  }
}
