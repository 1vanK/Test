// ==============================================
//
//    GameObject Base Class
//
// ==============================================

const int CTRL_ATTACK = (1 << 0);
const int CTRL_JUMP = (1 << 1);
const int CTRL_ALL = (1 << 16);

const int FLAGS_ATTACK  = (1 << 0);
const int FLAGS_COUNTER = (1 << 1);
const int FLAGS_REDIRECTED = (1 << 2);
const int FLAGS_NO_MOVE = (1 << 3);
const int FLAGS_MOVING = (1 << 4);
const int FLAGS_INVINCIBLE = (1 << 5);
const int FLAGS_STUN = (1 << 6);

const int COLLISION_LAYER_CHARACTER = (1 << 0);
const int COLLISION_LAYER_LANDSCAPE = (1 << 1);
const int COLLISION_LAYER_PROP      = (1 << 2);
const int COLLISION_LAYER_RAGDOLL   = (1 << 3);
const int COLLISION_LAYER_ATTACK    = (1 << 4);

class GameObject : ScriptObject
{
    float   duration = -1;
    int     flags = 0;
    int     side = 0;
    float   timeScale = 1.0f;

    GameObject()
    {

    }

    void Start()
    {

    }

    void Stop()
    {
        if (node !is null)
            Print(node.name + ".Stop()");
        else
            Print(GetName() + ".Stop()");
    }

    void SetTimeScale(float scale)
    {
        timeScale = scale;
        Print(GetName() + " SetTimeScale:" + scale);
    }

    void FixedUpdate(float timeStep)
    {
        timeStep *= timeScale;
        CheckDuration(timeStep);
    }

    void CheckDuration(float timeStep)
    {
        // Disappear when duration expired
        if (duration >= 0)
        {
            duration -= timeStep;
            if (duration <= 0)
                Remove();
        }
    }

    void Update(float timeStep)
    {
        timeStep *= timeScale;
    }

    void PlaySound(const String&in soundName)
    {
        // Create the sound channel
        SoundSource3D@ source = GetNode().CreateComponent("SoundSource3D");
        //SoundSource@ source = GetNode().CreateComponent("SoundSource");
        Sound@ sound = cache.GetResource("Sound", soundName);
        source.SetDistanceAttenuation(5, 50, 2);
        source.Play(sound);
        source.soundType = SOUND_EFFECT;
        source.frequency = source.frequency * GetNode().scene.timeScale * timeScale;
        // Subscribe to sound finished for cleaning up the source
        SubscribeToEvent(node, "SoundFinished", "HandleSoundFinished");
    }

    void HandleSoundFinished(StringHash eventType, VariantMap& eventData)
    {
        SoundSource3D@ source = eventData["SoundSource"].GetPtr();
        source.Remove();
    }

    void DebugDraw(DebugRenderer@ debug)
    {

    }

    String GetDebugText()
    {
        return "";
    }

    String GetName()
    {
        return "";
    }

    void AddFlag(int flag)
    {
        flags |= flag;
    }

    void RemoveFlag(int flag)
    {
        flags &= ~flag;
    }

    bool HasFlag(int flag)
    {
        return flags & flag != 0;
    }

    void Reset()
    {

    }

    bool OnDamage(GameObject@ attacker, const Vector3&in position, const Vector3&in direction, int damage, bool weak = false)
    {
        return true;
    }

    Node@ GetNode()
    {
        return null;
    }

    Scene@ GetScene()
    {
        Node@ _node = GetNode();
        if (_node is null)
            return null;
        return _node.scene;
    }

    void SetSceneTimeScale(float scale)
    {
        Scene@ _scene = GetScene();
        if (_scene is null)
            return;
        if (_scene.timeScale == scale)
            return;
        _scene.timeScale = scale;
        gGame.OnSceneTimeScaleUpdated(_scene, scale);
        Print(GetName() + " SetSceneTimeScale:" + scale);
    }

    void Transform(const Vector3& pos, const Quaternion& qua)
    {
        Node@ _node = GetNode();
        _node.worldPosition = pos;
        _node.worldRotation = qua;
    }

    void Remove()
    {
        Print(node.name + ".Remove()");
        node.Remove();
    }

    bool IsVisible()
    {
        return true;
    }
};


void AddDebugMark(DebugRenderer@ debug, const Vector3&in position, const Color&in color, float size=0.15f)
{
    Sphere sp;
    sp.Define(position, size);
    debug.AddSphere(sp, color, false);
}

void SetWorldTimeScale(Scene@ _scene, float scale)
{
    Print("SetWorldTimeScale:" + scale);
    Array<Node@> nodes = _scene.GetChildrenWithScript(false);
    for (uint i=0; i<nodes.length; ++i)
    {
        GameObject@ object = cast<GameObject>(nodes[i].scriptObject);
        if (object is null)
            continue;
        object.SetTimeScale(scale);
    }
}