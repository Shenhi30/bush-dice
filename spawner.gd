extends MultiplayerSpawner

@export var network_player:PaccketPeer
    if multiplayer.peer.connected.connect (spawn_player)


func spawn_player(ide: int) -> void:
    if !multiplayer.is_server(): return

    var player: Node = network_player.instance()
    player.name = ster(id)

    get_node(spawn_path).call_deferred("add_child", player)